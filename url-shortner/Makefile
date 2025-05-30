CLUSTER_NAME=kind-url-shortener
NAMESPACE=url-shortener
CHART_NAME=url-shortner
KONG_VALUES=infra/helm/kong-values.yaml

.PHONY: clean bootstrap build-image install-redis install monitoring rebuild test test-url

clean:
	kind delete cluster --name $(CLUSTER_NAME)
	-docker rm -f $$(docker ps -q --filter "publish=18443") || true
	-docker network prune -f
bootstrap:
	kind create cluster --name $(CLUSTER_NAME) --config infra/kind/kind-config.yaml
	kubectl cluster-info --context kind-$(CLUSTER_NAME)
	helm repo add kong https://charts.konghq.com
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update
	helm install kong kong/kong --namespace $(NAMESPACE) --create-namespace -f $(KONG_VALUES)

build-image:
	docker build -t url-shortener-app:latest -f app/Dockerfile .
	kind load docker-image url-shortener-app:latest --name $(CLUSTER_NAME)

install-redis:
	helm install redis bitnami/redis --namespace $(NAMESPACE) \
		--set architecture=standalone \
		--set auth.enabled=false

install:
	helm upgrade --install $(CHART_NAME) charts/url-shortner/ --namespace $(NAMESPACE)

monitoring:
	helm install prometheus prometheus-community/kube-prometheus-stack --namespace $(NAMESPACE) \
		--set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
	helm install grafana grafana/grafana --namespace $(NAMESPACE) \
		--set admin.password=admin

rebuild: clean bootstrap build-image install-redis install

test:
	curl -X POST http://localhost/shorten \
	 -H "Content-Type: application/json" \
	 -d '{"url":"https://example.com"}'

# make test-url ID=90ad0e66, for test the short url 
test-url:
	curl -i http://localhost/$(ID)