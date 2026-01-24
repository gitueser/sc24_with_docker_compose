# Bring the cluster up from scratch:
# make up

# Equivalent to:
# * helm lint
# * helm dependency update
# * create a namespace
# * apply all manifests
# * show status

# Completely tear down the cluster:
# make down
# deletes the namespace → everything inside

# Rebuild "from scratch":
# make clean up

# Check the current state:
# make status

# Quickly check that Eureka is alive:
# make check

# View gateway logs:
# make logs

# ================

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
