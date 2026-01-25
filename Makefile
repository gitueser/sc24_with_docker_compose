# ==============================================================================
# Selmag local k8s (minikube/WSL2) workflow via Helm umbrella chart
#
# Основная идея:
# - Всегда деплоим через Helm: helm upgrade --install
# - Observability включаем/выключаем overlay values-файлом
# - Проверки делаем простыми smoke-check'ами (curl внутри кластера и/или через ingress)
# ==============================================================================

NAMESPACE := selmag-helm
CHART := helm/selmag
RELEASE := selmag

# ----- Values files -----
VALUES_BASE := helm/selmag/values.yaml
VALUES_OBS  := helm/selmag/values-observability.yaml

# ----- Observability endpoints -----
GRAFANA_SVC := selmag-grafana-svc
VM_SVC := selmag-victoria-metrics-svc
TEMPO_SVC := selmag-tempo-svc
LOKI_SVC := selmag-loki-svc

GRAFANA_PORT := 3000
VM_PORT := 8428
TEMPO_HTTP_PORT := 3200
LOKI_PORT := 3100

# Как в твоём Ingress манифесте (nip.io на IP minikube)
GRAFANA_INGRESS_HOST := grafana.selm.ag.192.168.49.2.nip.io

# ==============================================================================
# Внутренняя "функция" make для запуска curl внутри namespace.
# Зачем:
# - проверки ClusterIP/DNS стабильны и не зависят от WSL/Windows networking
# - не нужно делать port-forward
# Как работает:
# - kubectl run создаёт одноразовый pod tmp-curl
# - curl выполняется внутри pod'а
# - pod удаляется автоматически (--rm)
# ==============================================================================
define KUBE_CURL
kubectl -n $(NAMESPACE) run tmp-curl --rm -i --restart=Never --image=curlimages/curl -- \
  sh -lc '$(1)'
endef


.PHONY: help \
        up obs-on obs-off \
        install upgrade \
        down clean namespace \
        deps lint render \
        status rollout events values \
        logs check eureka-apps \
        obs-check vm-check loki-check tempo-check grafana-svc-check grafana-ingress-check

help:
	@echo "Targets:"
	@echo "  make up           - Установить/обновить базовый стек (без observability)"
	@echo "  make obs-on       - Включить observability (overlay values)"
	@echo "  make obs-off      - Выключить observability (вернуться к base values)"
	@echo "  make status       - Показать состояние ресурсов"
	@echo "  make rollout      - Подождать rollout всех Deployments"
	@echo "  make check        - Быстрая проверка Eureka (HTTP 200 на /)"
	@echo "  make eureka-apps  - Проверка регистрации основных приложений в Eureka"
	@echo "  make obs-check    - Smoke checks observability endpoints"
	@echo "  make logs         - Логи api-gateway (tail)"
	@echo "  make events       - Последние события в namespace"
	@echo "  make values       - Показать user-supplied values текущего релиза"
	@echo "  make down         - Удалить релиз Helm (оставить namespace)"
	@echo "  make clean        - Полная очистка: удалить namespace целиком"


# ==============================================================================
# Namespace management
# ==============================================================================

namespace:
	# Создаём namespace, если его нет (idempotent)
	kubectl get ns $(NAMESPACE) >/dev/null 2>&1 || kubectl create ns $(NAMESPACE)

clean:
	# Полная очистка окружения (удаляет ВСЕ ресурсы внутри namespace)
	# Важно: удаление namespace удалит и PVC/секреты/конфиги в нём.
	kubectl delete ns $(NAMESPACE) --ignore-not-found

down:
	# Удаляем Helm-релиз (namespace при этом остаётся)
	# Это "мягче", чем clean: можно быстро переустановить без пересоздания ns.
	helm uninstall $(RELEASE) -n $(NAMESPACE) || true


# ==============================================================================
# Helm: deps -> lint (best practice for umbrella chart)
# ==============================================================================

deps:
	# Подтягиваем/обновляем зависимости umbrella chart.
	# Для file:// зависимостей Helm пакует subcharts и кладёт их в helm/selmag/charts/
	helm dependency update $(CHART)

lint: deps
	# Линтим уже "собранный" chart вместе с зависимостями.
	# Это убирает warning вида "chart directory is missing these dependencies ..."
	helm lint $(CHART)

render: deps
	# Рендер шаблонов в YAML без применения в кластер.
	# Полезно для отладки: можно посмотреть итоговые манифесты.
	helm template $(RELEASE) $(CHART) -n $(NAMESPACE) -f $(VALUES_BASE) > /tmp/selmag.rendered.yaml
	@echo "Rendered to /tmp/selmag.rendered.yaml"


# ==============================================================================
# Deploy workflows
# ==============================================================================

up: lint namespace install status rollout
	@echo "Base stack is up"

install:
	# Установка/обновление базового стека (без observability)
	# --atomic: если что-то не поднялось в таймаут — Helm откатит релиз
	# --timeout: общий таймаут на установку (включая ожидание готовности)
	helm upgrade --install $(RELEASE) $(CHART) \
	  -n $(NAMESPACE) \
	  -f $(VALUES_BASE) \
	  --atomic --timeout 10m

upgrade: install
	@true

obs-on: lint namespace
	# Включаем observability:
	# - подключаем overlay values файл
	# - профили observability для бизнес-сервисов задаются ТОЛЬКО в overlay,
	#   поэтому obs-off возвращает их обратно.
	helm upgrade $(RELEASE) $(CHART) \
	  -n $(NAMESPACE) \
	  -f $(VALUES_BASE) \
	  -f $(VALUES_OBS) \
	  --atomic --timeout 15m
	$(MAKE) status
	$(MAKE) rollout
	@echo "Observability is ON"

obs-off: lint namespace
	# Выключаем observability:
	# - деплоим только base values
	# - observability чарты выключаются, профили у сервисов откатываются на base
	helm upgrade $(RELEASE) $(CHART) \
	  -n $(NAMESPACE) \
	  -f $(VALUES_BASE) \
	  --atomic --timeout 10m
	$(MAKE) status
	$(MAKE) rollout
	@echo "Observability is OFF"


# ==============================================================================
# Cluster inspection / troubleshooting
# ==============================================================================

status:
	# Срез по основным типам ресурсов
	kubectl -n $(NAMESPACE) get deploy,sts,po,svc,ingress,pvc,cm,secret

rollout:
	# Ожидаем rollout ВСЕХ deployments в namespace.
	# Примечание: это не "probe-ready" проверка приложений, а проверка, что Deployment завершил rollout.
	kubectl -n $(NAMESPACE) get deploy -o name | xargs -n1 kubectl -n $(NAMESPACE) rollout status --timeout=300s

events:
	# Последние события (часто показывает причины рестартов/failed probes)
	kubectl -n $(NAMESPACE) get events --sort-by=.lastTimestamp | tail -n 50

values:
	# Текущие user-supplied values, которые реально применены к релизу
	helm get values $(RELEASE) -n $(NAMESPACE)

logs:
	# Быстрый tail логов gateway (как центральной точки входа)
	kubectl -n $(NAMESPACE) logs deploy/selmag-api-gateway-deployment --tail=200

check:
	# Быстрая проверка доступности Eureka по ClusterIP (200 на /)
	$(call KUBE_CURL, curl -sS -o /dev/null -w "%{http_code}\n" http://selmag-eureka-server-svc:8761/)

eureka-apps:
	# Проверяем, что основные приложения зарегистрированы в Eureka.
	# Выводит только совпавшие строки (если ничего не вывел — стоит смотреть логи сервисов/еврику).
	$(call KUBE_CURL, \
	  curl -sS http://selmag-eureka-server-svc:8761/eureka/apps | \
	  grep -E "SELMAG-(CATALOGUE-SERVICE|FEEDBACK-SERVICE|CUSTOMER-APP|MANAGER-APP|API-GATEWAY)" -n || true \
	)


# ==============================================================================
# Observability smoke checks
# ==============================================================================

obs-check: vm-check loki-check tempo-check grafana-svc-check grafana-ingress-check
	@echo "OK: observability basic checks passed"

vm-check:
	# VictoriaMetrics: Prometheus-compatible endpoint buildinfo должен отвечать 200
	$(call KUBE_CURL, curl -fsS -o /dev/null http://$(VM_SVC):$(VM_PORT)/api/v1/status/buildinfo)

loki-check:
	# Loki: /ready — стандартный readiness endpoint (200)
	$(call KUBE_CURL, curl -fsS -o /dev/null http://$(LOKI_SVC):$(LOKI_PORT)/ready)

tempo-check:
	# Tempo: /ready — стандартный readiness endpoint (200)
	$(call KUBE_CURL, curl -fsS -o /dev/null http://$(TEMPO_SVC):$(TEMPO_HTTP_PORT)/ready)

grafana-svc-check:
	# Grafana по service: часто отдаёт редирект на /login (302). Считаем 200 или 302 успехом.
	$(call KUBE_CURL, \
	  code=$$(curl -sS -o /dev/null -w "%{http_code}" http://$(GRAFANA_SVC):$(GRAFANA_PORT)/); \
	  test "$$code" = "200" -o "$$code" = "302" \
	)

grafana-ingress-check:
	# Grafana по ingress: также допускаем 200/302.
	@code=$$(curl -sS -o /dev/null -w "%{http_code}" http://$(GRAFANA_INGRESS_HOST)/ || true); \
	  if [ "$$code" = "200" ] || [ "$$code" = "302" ]; then \
	    echo "Grafana ingress OK (HTTP $$code)"; \
	  else \
	    echo "Grafana ingress FAIL (HTTP $$code)"; \
	    exit 1; \
	  fi
