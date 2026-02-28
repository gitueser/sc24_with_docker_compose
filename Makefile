# ==============================================================================
# Selmag local k8s (minikube/WSL2) workflow via Helm umbrella chart
#
# Базовый workflow:
#   make up              - базовый стек (без observability)
#   make obs-on          - включить observability
#   make obs-off         - выключить observability
#
# Частые операции по конкретному сервису (универсально через SVC=...):
#   make svc-info    SVC=feedback-service
#   make svc-status  SVC=feedback-service
#   make svc-pods    SVC=feedback-service
#   make svc-logs    SVC=feedback-service [LINES=200] [FOLLOW=1]
#   make svc-restart SVC=feedback-service
#   make svc-rollout SVC=feedback-service
#   make svc-stop    SVC=feedback-service      # deploy/sts -> scale 0; ds -> delete
#   make svc-start   SVC=feedback-service      # deploy/sts -> scale back to default replicas
#   make svc-delete  SVC=feedback-service      # delete workload (Helm потом вернёт при upgrade)
#   make svc-describe SVC=feedback-service     # describe первого pod по app-label
#
# Алиасы без SVC (для всех сервисов ниже):
#   make feedback-service-restart
#   make feedback-service-logs
#   make feedback-service-stop
#   ...
#
# Важно:
# - Все команды "svc-*" используют стабильные имена workload’ов (Deployment/StatefulSet/DaemonSet),
#   НЕ зависят от pod-template-hash’ей.
# - Для DaemonSet "stop" реализован как delete ds/<name> (у DS нет scale).
#   Вернуть DS обратно: make obs-on (или helm upgrade как у тебя).
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

# Promtail (DaemonSet)
PROMTAIL_DS := selmag-promtail
PROMTAIL_LABEL := app=selmag-promtail
PROMTAIL_PORT := 9080

# Как в твоём Ingress манифесте (nip.io на IP minikube)
GRAFANA_INGRESS_HOST := grafana.selm.ag.192.168.49.2.nip.io

# ==============================================================================
# Make "helpers"
# ==============================================================================

# curl inside cluster (stable for ClusterIP/DNS)
define KUBE_CURL
kubectl -n $(NAMESPACE) run tmp-curl --rm -i --restart=Never --image=curlimages/curl -- \
  sh -lc '$(1)'
endef

# upper-case helper (used to map SVC -> variables)
define UC
$(shell echo $(1) | tr '[:lower:]' '[:upper:]')
endef

# Convert "feedback-service" -> "FEEDBACK_SERVICE"
SVC_KEY := $(call UC,$(subst -,_,$(SVC)))

# Defaults for logs
LINES ?= 200
FOLLOW ?= 0

# ==============================================================================
# Inventory (from your kubectl outputs)
# Canonical SVC ids:
#   admin-server, api-gateway, catalogue-service, config-server, customer-app,
#   eureka-server, feedback-service, keycloak,
#   catalogue-db, feedback-db,
#   grafana, loki, tempo, victoria-metrics,
#   promtail
# ==============================================================================

SERVICES := \
  admin-server api-gateway catalogue-service config-server customer-app eureka-server feedback-service \
  keycloak manager-app \
  catalogue-db feedback-db \
  grafana loki tempo victoria-metrics promtail

# --- Deployments ---
ADMIN_SERVER_KIND := deploy
ADMIN_SERVER_NAME := selmag-admin-server-deployment
ADMIN_SERVER_APP  := selmag-admin-server
ADMIN_SERVER_REPLICAS := 1

API_GATEWAY_KIND := deploy
API_GATEWAY_NAME := selmag-api-gateway-deployment
API_GATEWAY_APP  := selmag-api-gateway
API_GATEWAY_REPLICAS := 1

CATALOGUE_SERVICE_KIND := deploy
CATALOGUE_SERVICE_NAME := selmag-catalogue-service-deployment
CATALOGUE_SERVICE_APP  := selmag-catalogue-service
CATALOGUE_SERVICE_REPLICAS := 3

CONFIG_SERVER_KIND := deploy
CONFIG_SERVER_NAME := selmag-config-server-deployment
CONFIG_SERVER_APP  := selmag-config-server
CONFIG_SERVER_REPLICAS := 1

CUSTOMER_APP_KIND := deploy
CUSTOMER_APP_NAME := selmag-customer-app-deployment
CUSTOMER_APP_APP  := selmag-customer-app
CUSTOMER_APP_REPLICAS := 1

EUREKA_SERVER_KIND := deploy
EUREKA_SERVER_NAME := selmag-eureka-server-deployment
EUREKA_SERVER_APP  := selmag-eureka-server
EUREKA_SERVER_REPLICAS := 1

FEEDBACK_SERVICE_KIND := deploy
FEEDBACK_SERVICE_NAME := selmag-feedback-service-deployment
FEEDBACK_SERVICE_APP  := selmag-feedback-service
FEEDBACK_SERVICE_REPLICAS := 1

MANAGER_APP_KIND := deploy
MANAGER_APP_NAME := selmag-manager-app-deployment
MANAGER_APP_APP  := selmag-manager-app
MANAGER_APP_REPLICAS := 1

KEYCLOAK_KIND := deploy
KEYCLOAK_NAME := selmag-keycloak
KEYCLOAK_APP  := selmag-keycloak
KEYCLOAK_REPLICAS := 1

GRAFANA_KIND := deploy
GRAFANA_NAME := selmag-grafana-deployment
GRAFANA_APP  := selmag-grafana
GRAFANA_REPLICAS := 1

LOKI_KIND := deploy
LOKI_NAME := selmag-loki-deployment
LOKI_APP  := selmag-loki
LOKI_REPLICAS := 1

TEMPO_KIND := deploy
TEMPO_NAME := selmag-tempo-deployment
TEMPO_APP  := selmag-tempo
TEMPO_REPLICAS := 1

VICTORIA_METRICS_KIND := deploy
VICTORIA_METRICS_NAME := selmag-victoria-metrics-deployment
VICTORIA_METRICS_APP  := selmag-victoria-metrics
VICTORIA_METRICS_REPLICAS := 1

# --- StatefulSets ---
CATALOGUE_DB_KIND := sts
CATALOGUE_DB_NAME := selmag-catalogue-db
CATALOGUE_DB_APP  := selmag-catalogue-db
CATALOGUE_DB_REPLICAS := 1

FEEDBACK_DB_KIND := sts
FEEDBACK_DB_NAME := selmag-feedback-db
FEEDBACK_DB_APP  := selmag-feedback-db
FEEDBACK_DB_REPLICAS := 1

# --- DaemonSet ---
PROMTAIL_KIND := ds
PROMTAIL_NAME := selmag-promtail
PROMTAIL_APP  := selmag-promtail
PROMTAIL_REPLICAS := 1

# ==============================================================================
# Targets
# ==============================================================================

.PHONY: help \
        up obs-on obs-off install upgrade down clean namespace \
        deps lint render \
        status rollout events values \
        logs check eureka-apps \
        obs-check vm-check loki-check loki-logs-check tempo-check grafana-svc-check grafana-ingress-check grafana-health-check promtail-check \
        svc-list svc-info svc-status svc-pods svc-logs svc-restart svc-rollout svc-stop svc-start svc-delete svc-describe \
        $(addsuffix -status,$(SERVICES)) \
        $(addsuffix -pods,$(SERVICES)) \
        $(addsuffix -logs,$(SERVICES)) \
        $(addsuffix -restart,$(SERVICES)) \
        $(addsuffix -rollout,$(SERVICES)) \
        $(addsuffix -stop,$(SERVICES)) \
        $(addsuffix -start,$(SERVICES)) \
        $(addsuffix -delete,$(SERVICES)) \
        $(addsuffix -describe,$(SERVICES))

help:
	@echo "Targets:"
	@echo "  make up                - Установить/обновить базовый стек (без observability)"
	@echo "  make obs-on            - Включить observability (overlay values)"
	@echo "  make obs-off           - Выключить observability (вернуться к base values)"
	@echo "  make status            - Показать состояние ресурсов"
	@echo "  make rollout           - Подождать rollout всех Deployments"
	@echo "  make check             - Быстрая проверка Eureka (HTTP 200 на /)"
	@echo "  make eureka-apps       - Проверка регистрации основных приложений в Eureka"
	@echo "  make obs-check         - Smoke checks observability endpoints"
	@echo "  make logs              - Логи api-gateway (tail)"
	@echo "  make events            - Последние события в namespace"
	@echo "  make values            - Показать user-supplied values текущего релиза"
	@echo "  make down              - Удалить релиз Helm (оставить namespace)"
	@echo "  make clean             - Полная очистка: удалить namespace целиком"
	@echo ""
	@echo "Per-service ops (generic):"
	@echo "  make svc-list"
	@echo "  make svc-info    SVC=<id>"
	@echo "  make svc-status  SVC=<id>"
	@echo "  make svc-pods    SVC=<id>"
	@echo "  make svc-logs    SVC=<id> [LINES=200] [FOLLOW=1]"
	@echo "  make svc-restart SVC=<id>"
	@echo "  make svc-rollout SVC=<id>"
	@echo "  make svc-stop    SVC=<id>"
	@echo "  make svc-start   SVC=<id>"
	@echo "  make svc-delete  SVC=<id>"
	@echo "  make svc-describe SVC=<id>"
	@echo ""
	@echo "Example:"
	@echo "  make svc-restart SVC=feedback-service"
	@echo "  make svc-logs    SVC=feedback-service FOLLOW=1"
	@echo ""
	@echo "Aliases (without SVC=...):"
	@echo "  <service>-restart / <service>-logs / <service>-stop / <service>-start / <service>-delete / <service>-status / <service>-pods"
	@echo "Services:"
	@echo "  $(SERVICES)"


# ==============================================================================
# Namespace management
# ==============================================================================

namespace:
	kubectl get ns $(NAMESPACE) >/dev/null 2>&1 || kubectl create ns $(NAMESPACE)

clean:
	kubectl delete ns $(NAMESPACE) --ignore-not-found

down:
	helm uninstall $(RELEASE) -n $(NAMESPACE) || true


# ==============================================================================
# Helm: deps -> lint (best practice for umbrella chart)
# ==============================================================================

deps:
	helm dependency update $(CHART)

lint: deps
	helm lint $(CHART)

render: deps
	helm template $(RELEASE) $(CHART) -n $(NAMESPACE) -f $(VALUES_BASE) > /tmp/selmag.rendered.yaml
	@echo "Rendered to /tmp/selmag.rendered.yaml"


# ==============================================================================
# Deploy workflows
# ==============================================================================

up: lint namespace install status rollout
	@echo "Base stack is up"

install:
	helm upgrade --install $(RELEASE) $(CHART) \
	  -n $(NAMESPACE) \
	  -f $(VALUES_BASE) \
	  --atomic --timeout 10m

upgrade: install
	@true

obs-on: lint namespace
	helm upgrade $(RELEASE) $(CHART) \
	  -n $(NAMESPACE) \
	  -f $(VALUES_BASE) \
	  -f $(VALUES_OBS) \
	  --atomic --timeout 15m
	$(MAKE) status
	$(MAKE) rollout
	@echo "Observability is ON"

obs-off: lint namespace
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
	kubectl -n $(NAMESPACE) get deploy,sts,ds,po,svc,ingress,pvc,cm,secret

rollout:
	kubectl -n $(NAMESPACE) get deploy -o name | xargs -n1 kubectl -n $(NAMESPACE) rollout status --timeout=300s

events:
	kubectl -n $(NAMESPACE) get events --sort-by=.lastTimestamp | tail -n 50

values:
	helm get values $(RELEASE) -n $(NAMESPACE)

logs:
	kubectl -n $(NAMESPACE) logs deploy/selmag-api-gateway-deployment --tail=200

check:
	$(call KUBE_CURL, curl -sS -o /dev/null -w "%{http_code}\n" http://selmag-eureka-server-svc:8761/)

eureka-apps:
	$(call KUBE_CURL, \
	  curl -sS http://selmag-eureka-server-svc:8761/eureka/apps | \
	  grep -E "SELMAG-(CATALOGUE-SERVICE|FEEDBACK-SERVICE|CUSTOMER-APP|MANAGER-APP|API-GATEWAY)" -n || true \
	)


# ==============================================================================
# Observability smoke checks
# ==============================================================================

obs-check: vm-check loki-check tempo-check grafana-svc-check grafana-health-check grafana-ingress-check promtail-check loki-logs-check
	@echo "OK: observability basic checks passed"

vm-check:
	$(call KUBE_CURL, curl -fsS -o /dev/null http://$(VM_SVC):$(VM_PORT)/api/v1/status/buildinfo)

loki-check:
	$(call KUBE_CURL, curl -fsS -o /dev/null http://$(LOKI_SVC):$(LOKI_PORT)/ready)

tempo-check:
	$(call KUBE_CURL, curl -fsS -o /dev/null http://$(TEMPO_SVC):$(TEMPO_HTTP_PORT)/ready)

grafana-svc-check:
	$(call KUBE_CURL, \
	  code=$$(curl -sS -o /dev/null -w "%{http_code}" http://$(GRAFANA_SVC):$(GRAFANA_PORT)/); \
	  test "$$code" = "200" -o "$$code" = "302" \
	)

grafana-health-check:
	$(call KUBE_CURL, curl -fsS http://$(GRAFANA_SVC):$(GRAFANA_PORT)/api/health)

grafana-ingress-check:
	@code=$$(curl -sS -o /dev/null -w "%{http_code}" http://$(GRAFANA_INGRESS_HOST)/ || true); \
	  if [ "$$code" = "200" ] || [ "$$code" = "302" ]; then \
	    echo "Grafana ingress OK (HTTP $$code)"; \
	  else \
	    echo "Grafana ingress FAIL (HTTP $$code)"; \
	    exit 1; \
	  fi

promtail-check:
	@set -e; \
	  kubectl -n $(NAMESPACE) get ds/$(PROMTAIL_DS) >/dev/null; \
	  kubectl -n $(NAMESPACE) rollout status ds/$(PROMTAIL_DS) --timeout=180s; \
	  pod_ip=$$(kubectl -n $(NAMESPACE) get pod -l $(PROMTAIL_LABEL) -o jsonpath='{.items[0].status.podIP}'); \
	  if [ -z "$$pod_ip" ]; then echo "ERROR: Promtail pod IP is empty"; exit 1; fi; \
	  echo "Promtail pod IP: $$pod_ip"; \
	  echo "Checking Promtail /metrics (must be 200)..."; \
	  kubectl -n $(NAMESPACE) run tmp-curl --rm -i --restart=Never --image=curlimages/curl -- \
	    sh -lc "curl -fsS -o /dev/null http://$$pod_ip:$(PROMTAIL_PORT)/metrics"; \
	  echo "Promtail /metrics OK"; \
	  echo "Checking Promtail /ready (informational)..."; \
	  kubectl -n $(NAMESPACE) run tmp-curl --rm -i --restart=Never --image=curlimages/curl -- \
	    sh -lc "code=\$$(curl -sS -o /dev/null -w '%{http_code}' http://$$pod_ip:$(PROMTAIL_PORT)/ready || true); \
	           echo \"Promtail /ready HTTP \$$code\"; \
	           if [ \"\$$code\" != \"200\" ]; then \
	             echo \"NOTE: /ready is not 200 yet. This can be normal until Promtail starts tailing logs.\"; \
	           fi"

# Loki: проверка, что в Loki реально есть логи (query_range за последние 5 минут)
loki-logs-check:
	@set -e; \
	  echo "Checking Loki has logs for app=selmag-api-gateway (last 5m)..."; \
	  kubectl -n $(NAMESPACE) run tmp-curl --rm -i --restart=Never --image=curlimages/curl -- \
	    sh -lc 'set -e; \
	      end=$$(date +%s); start=$$((end-300)); \
	      query="{app=\"selmag-api-gateway\",namespace=\"$(NAMESPACE)\"}"; \
	      resp=$$(curl -fsS --get \
	        --data-urlencode "query=$$query" \
	        --data-urlencode "start=$${start}000000000" \
	        --data-urlencode "end=$${end}000000000" \
	        --data-urlencode "limit=50" \
	        http://$(LOKI_SVC):$(LOKI_PORT)/loki/api/v1/query_range); \
	      echo "$$resp" | grep -Eq "\"status\"[[:space:]]*:[[:space:]]*\"success\"" || { \
	        echo "ERROR: Loki API did not return success"; echo "$$resp"; exit 1; }; \
	      echo "$$resp" | grep -Eq "\"result\"[[:space:]]*:[[:space:]]*\\[[[:space:]]*\\]" && { \
	        echo "ERROR: Loki returned empty result (no logs found in last 5m)"; echo "$$resp"; exit 1; }; \
	      echo "OK: Loki returned non-empty result (logs exist)"; \
	    '


# ==============================================================================
# Per-service operations (generic via SVC=...)
# ==============================================================================

svc-list:
	@echo "$(SERVICES)"

svc-info:
	@set -e; \
	  if [ -z "$(SVC)" ]; then echo "ERROR: set SVC=<one of: $(SERVICES)>"; exit 2; fi; \
	  kind="$($(SVC_KEY)_KIND)"; name="$($(SVC_KEY)_NAME)"; app="$($(SVC_KEY)_APP)"; rep="$($(SVC_KEY)_REPLICAS)"; \
	  if [ -z "$$kind" ] || [ -z "$$name" ] || [ -z "$$app" ]; then \
	    echo "ERROR: unknown SVC='$(SVC)'. Allowed: $(SERVICES)"; exit 2; \
	  fi; \
	  echo "SVC=$(SVC)"; \
	  echo "  kind=$$kind"; \
	  echo "  name=$$name"; \
	  echo "  app=$$app"; \
	  echo "  replicas(default)=$$rep"

svc-status:
	@set -e; \
	  kind="$($(SVC_KEY)_KIND)"; name="$($(SVC_KEY)_NAME)"; \
	  if [ -z "$$kind" ] || [ -z "$$name" ]; then echo "ERROR: unknown SVC='$(SVC)'"; exit 2; fi; \
	  kubectl -n $(NAMESPACE) get $$kind/$$name -o wide

svc-pods:
	@set -e; \
	  app="$($(SVC_KEY)_APP)"; \
	  if [ -z "$$app" ]; then echo "ERROR: unknown SVC='$(SVC)'"; exit 2; fi; \
	  kubectl -n $(NAMESPACE) get pods -l app=$$app -o wide

svc-logs:
	@set -e; \
	  app="$($(SVC_KEY)_APP)"; \
	  if [ -z "$$app" ]; then echo "ERROR: unknown SVC='$(SVC)'"; exit 2; fi; \
	  if [ "$(FOLLOW)" = "1" ]; then \
	    kubectl -n $(NAMESPACE) logs -l app=$$app --tail=$(LINES) -f; \
	  else \
	    kubectl -n $(NAMESPACE) logs -l app=$$app --tail=$(LINES); \
	  fi

svc-rollout:
	@set -e; \
	  kind="$($(SVC_KEY)_KIND)"; name="$($(SVC_KEY)_NAME)"; \
	  if [ -z "$$kind" ] || [ -z "$$name" ]; then echo "ERROR: unknown SVC='$(SVC)'"; exit 2; fi; \
	  kubectl -n $(NAMESPACE) rollout status $$kind/$$name --timeout=300s

svc-restart:
	@set -e; \
	  kind="$($(SVC_KEY)_KIND)"; name="$($(SVC_KEY)_NAME)"; \
	  if [ -z "$$kind" ] || [ -z "$$name" ]; then echo "ERROR: unknown SVC='$(SVC)'"; exit 2; fi; \
	  kubectl -n $(NAMESPACE) rollout restart $$kind/$$name; \
	  kubectl -n $(NAMESPACE) rollout status $$kind/$$name --timeout=300s

# stop/start/delete:
# - deploy/sts: stop = scale 0, start = scale <default>
# - ds: stop/delete = kubectl delete ds/<name> (у DS нет scale)
svc-stop:
	@set -e; \
	  kind="$($(SVC_KEY)_KIND)"; name="$($(SVC_KEY)_NAME)"; \
	  if [ -z "$$kind" ] || [ -z "$$name" ]; then echo "ERROR: unknown SVC='$(SVC)'"; exit 2; fi; \
	  if [ "$$kind" = "ds" ]; then \
	    echo "NOTE: DaemonSet has no scale. Deleting ds/$$name"; \
	    kubectl -n $(NAMESPACE) delete ds/$$name --ignore-not-found; \
	  else \
	    kubectl -n $(NAMESPACE) scale $$kind/$$name --replicas=0; \
	    kubectl -n $(NAMESPACE) get $$kind/$$name -o wide; \
	  fi

svc-start:
	@set -e; \
	  kind="$($(SVC_KEY)_KIND)"; name="$($(SVC_KEY)_NAME)"; rep="$($(SVC_KEY)_REPLICAS)"; \
	  if [ -z "$$kind" ] || [ -z "$$name" ] || [ -z "$$rep" ]; then echo "ERROR: unknown SVC='$(SVC)'"; exit 2; fi; \
	  if [ "$$kind" = "ds" ]; then \
	    echo "ERROR: cannot 'start' DaemonSet via scale. Use: make obs-on (or helm upgrade) to restore ds/$$name"; \
	    exit 2; \
	  else \
	    kubectl -n $(NAMESPACE) scale $$kind/$$name --replicas=$$rep; \
	    kubectl -n $(NAMESPACE) rollout status $$kind/$$name --timeout=300s; \
	  fi

svc-delete:
	@set -e; \
	  kind="$($(SVC_KEY)_KIND)"; name="$($(SVC_KEY)_NAME)"; \
	  if [ -z "$$kind" ] || [ -z "$$name" ]; then echo "ERROR: unknown SVC='$(SVC)'"; exit 2; fi; \
	  kubectl -n $(NAMESPACE) delete $$kind/$$name --ignore-not-found

svc-describe:
	@set -e; \
	  app="$($(SVC_KEY)_APP)"; \
	  if [ -z "$$app" ]; then echo "ERROR: unknown SVC='$(SVC)'"; exit 2; fi; \
	  pod=$$(kubectl -n $(NAMESPACE) get pods -l app=$$app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true); \
	  if [ -z "$$pod" ]; then echo "ERROR: no pods found for app=$$app"; exit 1; fi; \
	  kubectl -n $(NAMESPACE) describe pod $$pod


# ==============================================================================
# Per-service aliases (no SVC=... required)
# ==============================================================================
# Usage:
#   make feedback-service-restart
#   make feedback-service-logs FOLLOW=1
#   make feedback-db-stop
#   make promtail-delete
# etc.

define MAKE_SERVICE_ALIASES
$(1)-info:
	@$(MAKE) svc-info SVC=$(1)

$(1)-status:
	@$(MAKE) svc-status SVC=$(1)

$(1)-pods:
	@$(MAKE) svc-pods SVC=$(1)

$(1)-logs:
	@$(MAKE) svc-logs SVC=$(1) LINES=$(LINES) FOLLOW=$(FOLLOW)

$(1)-restart:
	@$(MAKE) svc-restart SVC=$(1)

$(1)-rollout:
	@$(MAKE) svc-rollout SVC=$(1)

$(1)-stop:
	@$(MAKE) svc-stop SVC=$(1)

$(1)-start:
	@$(MAKE) svc-start SVC=$(1)

$(1)-delete:
	@$(MAKE) svc-delete SVC=$(1)

$(1)-describe:
	@$(MAKE) svc-describe SVC=$(1)
endef

$(foreach s,$(SERVICES),$(eval $(call MAKE_SERVICE_ALIASES,$(s))))
