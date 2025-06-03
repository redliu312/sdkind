.PHONY: cluster delete-cluster deploy init-sharding

cluster:
	kind create cluster --name mongo-shard-lab --config infra/kind-cluster.yaml

delete-cluster:
	kind delete cluster --name mongo-shard-lab

deploy: cluster
	helm install mongodb-sharded charts/mongodb-sharded

init-sharding:
	kubectl exec -it $(kubectl get pod -l app=mongos -o jsonpath="{.items[0].metadata.name}") -- \
	  mongosh < /scripts/setup-sharding.js
