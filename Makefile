# ==============================================================================
# Selmag umbrella (Helm) Makefile
#
# Переходим на "правильный" workflow:
#   - только helm upgrade --install / helm uninstall
#   - никаких helm template | kubectl apply
#
# Основная идея:
#   1) Базовый запуск (business-only) использует values.yaml
#   2) Запуск с observability использует два values файла:
#        values.yaml + values-observability.yaml
#
# Примеры:
#   make up          # поставить/обновить бизнес-стек
#   make up-obs      # поставить/обновить бизнес + observability
#   make obs-on      # включить observability поверх уже установленного релиза
#   make obs-off     # выключить observability, вернуться к business-only
#   make down        # удалить Helm релиз (ресурсы, созданные Helm'ом)
#   make purge       # удалить namespace (жестко снести всё включая PVC)
#   make clean       # purge + создать namespace заново
#
# Проверки:
#   make status      # kubectl get по основным ресурсам
#   make rollout     # дождаться rollout всех deploy в namespace
#   make check       # проверить, что Eureka отвечает 200
#   make eureka-apps # проверить, какие сервисы зарегистрированы в Eureka
#   make logs-gw     # последние 200 строк логов api-gateway
# ==============================================================================

# -----------------------
# Configuration
# -----------------------
NAMESPACE   := selmag-helm
RELEASE     := selmag
CHART       := helm/selmag

VALUES_BASE := $(CHART)/values.yaml
VALUES_OBS  := $(CHART)/values-observability.yaml

# Таймаут для spring/ключевого/прочих долгих стартов.
# Можно подстроить под железо.
TIMEOUT_BASE := 10m
TIMEOUT_OBS  := 15m

# Общие флаги Helm.
# --atomic: при ошибке раскатки откатывает релиз назад.
# --timeout: сколько ждать, пока ресурсы придут в состояние Ready.
HELM_FLAGS_BASE := --atomic --timeout $(TIMEOUT_BASE)
HELM_FLAGS_OBS  := --atomic --timeout $(TIMEOUT_OBS)

# -----------------------
# Phony targets
# -----------------------
.PHONY: help \
        lint deps namespace \
        up up-obs \
        obs-on obs-off \
        status rollout events \
        check eureka-apps \
        logs-gw logs \
        values manifest diff \
        down uninstall purge clean

help:
	@echo "Targets:"
	@echo "  make up           - Helm install/upgrade business-only (values.yaml)"
	@echo "  make up-obs       - Helm install/upgrade with observability overlay"
	@echo "  make obs-on       - Enable observability (upgrade with overlay)"
	@echo "  make obs-off      - Disable observability (upgrade without overlay)"
	@echo "  make status       - kubectl get main resources"
	@echo "  make rollout      - wait for rollout of all deployments"
	@echo "  make check        - curl Eureka via ClusterIP service (expect 200)"
	@echo "  make eureka-apps  - list registered services in Eureka"
	@echo "  make logs-gw      - last 200 lines from api-gateway deployment"
	@echo "  make logs         - alias for logs-gw"
	@echo "  make down         - helm uninstall release (keeps namespace)"
	@echo "  make purge        - delete namespace (DESTROYS PVC/DATA)"
	@echo "  make clean        - purge + recreate namespace"
	@echo "  make lint         - helm lint"
	@echo "  make deps         - helm dependency update"
	@echo "  make values       - show effective values for current release"
	@echo "  make manifest     - show rendered manifest for current release"
	@echo "  make diff         - show what Helm would change (server-side dry-run)"

# -----------------------
# Helm chart quality gates
# -----------------------

# helm lint CHART
# Проверяет структуру чарта, шаблоны, некоторые типичные ошибки.
lint:
	helm lint $(CHART)

# helm dependency update CHART
# Подтягивает/переупаковывает зависимости (subcharts), создает/обновляет Chart.lock.
deps:
	helm dependency update $(CHART)

# -----------------------
# Namespace management
# -----------------------

# Создать namespace, если его нет.
namespace:
	kubectl get ns $(NAMESPACE) >/dev/null 2>&1 || kubectl create ns $(NAMESPACE)

# -----------------------
# Install/Upgrade workflows
# -----------------------

# "Business-only" install/upgrade:
# helm upgrade --install RELEASE CHART -n NAMESPACE -f values.yaml --atomic --timeout ...
up: lint deps namespace
	helm upgrade --install $(RELEASE) $(CHART) \
	  -n $(NAMESPACE) \
	  -f $(VALUES_BASE) \
	  $(HELM_FLAGS_BASE)
	$(MAKE) status
	$(MAKE) rollout

# Install/upgrade with observability overlay:
# helm upgrade --install RELEASE CHART -n NAMESPACE -f values.yaml -f values-observability.yaml ...
up-obs: lint deps namespace
	helm upgrade --install $(RELEASE) $(CHART) \
	  -n $(NAMESPACE) \
	  -f $(VALUES_BASE) \
	  -f $(VALUES_OBS) \
	  $(HELM_FLAGS_OBS)
	$(MAKE) status
	$(MAKE) rollout

# Включить observability поверх уже стоящего релиза:
# Это просто upgrade с overlay values.
obs-on: deps namespace
	helm upgrade $(RELEASE) $(CHART) \
	  -n $(NAMESPACE) \
	  -f $(VALUES_BASE) \
	  -f $(VALUES_OBS) \
	  $(HELM_FLAGS_OBS)
	$(MAKE) status
	$(MAKE) rollout

# Выключить observability:
# Это upgrade БЕЗ overlay-файла.
# Helm удалит ресурсы observability-чартов, т.к. зависимости выпадут по condition *.enabled.
obs-off: deps namespace
	helm upgrade $(RELEASE) $(CHART) \
	  -n $(NAMESPACE) \
	  -f $(VALUES_BASE) \
	  $(HELM_FLAGS_BASE)
	$(MAKE) status
	$(MAKE) rollout

# -----------------------
# Visibility / Debug
# -----------------------

# Показать текущий статус ресурсов в namespace.
status:
	kubectl -n $(NAMESPACE) get deploy,sts,po,svc,ingress,pvc,cm,secret

# Дождаться раскатки всех Deployment.
# Важно: у kubectl нет rollout status --all, поэтому делаем через xargs.
rollout:
	kubectl -n $(NAMESPACE) get deploy -o name | xargs -n1 kubectl -n $(NAMESPACE) rollout status --timeout=300s

# Последние события — удобно для диагностики (pull image, readiness, scheduling и т.п.)
events:
	kubectl -n $(NAMESPACE) get events --sort-by=.lastTimestamp | tail -n 50

# Показать effective values релиза (что реально применено Helm'ом).
values:
	helm get values $(RELEASE) -n $(NAMESPACE)

# Показать отрендеренные манифесты текущего релиза (как их видит Helm).
manifest:
	helm get manifest $(RELEASE) -n $(NAMESPACE) | less

# Показать, что изменится при следующем upgrade (без применения):
# --dry-run=server: просит API-сервер провалидировать как будто применяем.
# Полезно перед реальным upgrade.
diff:
	helm upgrade $(RELEASE) $(CHART) \
	  -n $(NAMESPACE) \
	  -f $(VALUES_BASE) \
	  --dry-run=server

# -----------------------
# Service checks (smoke tests)
# -----------------------

# Проверка, что Eureka отвечает 200 по сервису внутри кластера.
# Важно: команда НЕ перезапускает Eureka.
check:
	kubectl -n $(NAMESPACE) run tmp-curl --rm -it --restart=Never \
	  --image=curlimages/curl -- \
	  sh -lc 'curl -sS -o /dev/null -w "%{http_code}\n" http://selmag-eureka-server-svc:8761/'

# Проверка, что сервисы зарегистрированы в Eureka (по списку).
eureka-apps:
	kubectl -n $(NAMESPACE) run tmp-curl --rm -it --restart=Never \
	  --image=curlimages/curl -- \
	  sh -lc 'curl -sS http://selmag-eureka-server-svc:8761/eureka/apps | grep -E "SELMAG-(CATALOGUE-SERVICE|FEEDBACK-SERVICE|CUSTOMER-APP|MANAGER-APP|API-GATEWAY)" -n || true'

# Логи api-gateway (последние 200 строк).
logs-gw:
	kubectl -n $(NAMESPACE) logs deploy/selmag-api-gateway-deployment --tail=200

# Алиас.
logs: logs-gw

# -----------------------
# Tear down
# -----------------------

# Удалить Helm релиз:
# Helm удалит все ресурсы, которые он создавал (в рамках релиза),
# но namespace останется, и PVC могут остаться если они "за пределами" релиза
# (в твоем кейсе PVC создаются чартами и обычно удаляются вместе с релизом,
# но зависит от политики и finalizers).
down: uninstall

uninstall:
	helm uninstall $(RELEASE) -n $(NAMESPACE) || true

# Жесткое удаление namespace (снесет ВСЁ внутри, включая PVC и данные).
purge:
	kubectl delete ns $(NAMESPACE) --ignore-not-found

# Полная пересборка окружения:
# purge + recreate namespace.
clean: purge
	kubectl create ns $(NAMESPACE)
