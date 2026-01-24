NAMESPACE := selmag-helm
CHART := helm/selmag
RELEASE := selmag

.PHONY: up down clean status logs check lint deps render

up: lint deps namespace apply status

down:
	kubectl delete ns $(NAMESPACE) --ignore-not-found

clean: down
	kubectl create ns $(NAMESPACE)

namespace:
	kubectl get ns $(NAMESPACE) >/dev/null 2>&1 || kubectl create ns $(NAMESPACE)

lint:
	helm lint $(CHART)

deps:
	helm dependency update $(CHART)

render:
	helm template $(RELEASE) $(CHART) -n $(NAMESPACE) > /tmp/selmag.rendered.yaml

apply:
	helm template $(RELEASE) $(CHART) -n $(NAMESPACE) | kubectl apply -n $(NAMESPACE) -f -

status:
	kubectl -n $(NAMESPACE) get all,ingress,pvc,cm,secret

logs:
	kubectl -n $(NAMESPACE) logs deploy/selmag-api-gateway-deployment --tail=200

check:
	kubectl -n $(NAMESPACE) run tmp-curl --rm -it --restart=Never \
	  --image=curlimages/curl -- \
	  sh -lc 'curl -sS -o /dev/null -w "%{http_code}\n" http://selmag-eureka-server-svc:8761/'
