mkdir -p mongo-shard-lab/{charts/mongodb-sharded/templates,infra,scripts}

cat > mongo-shard-lab/infra/kind-cluster.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 27017
        hostPort: 27017
        protocol: TCP
EOF

cat > mongo-shard-lab/Makefile <<EOF
cluster:
\tkind create cluster --config infra/kind-cluster.yaml

deploy:
\thelm install mongodb-sharded charts/mongodb-sharded

init-sharding:
\tkubectl exec -it \$(kubectl get pod -l app=mongos -o jsonpath="{.items[0].metadata.name}") -- \
\t  mongosh < /scripts/setup-sharding.js
EOF

cat > mongo-shard-lab/charts/mongodb-sharded/Chart.yaml <<EOF
apiVersion: v2
name: mongodb-sharded
description: A Helm chart for MongoDB sharding setup
type: application
version: 0.1.0
appVersion: "6.0"
EOF

cat > mongo-shard-lab/charts/mongodb-sharded/values.yaml <<EOF
replicaSetName: shard1
shards:
  - name: shard1
  - name: shard2
configReplSet: configReplSet
mongos:
  replicas: 1
EOF

cat > mongo-shard-lab/charts/mongodb-sharded/templates/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongos
  template:
    metadata:
      labels:
        app: mongos
    spec:
      containers:
        - name: mongos
          image: mongo:6.0
          command: ["mongos"]
          args: ["--configdb", "configReplSet/configsvr-0.mongodb:27017"]
          ports:
            - containerPort: 27017
EOF

cat > mongo-shard-lab/scripts/setup-sharding.js <<EOF
sh.addShard("shard1/shard1-0.mongodb:27017");
sh.addShard("shard2/shard2-0.mongodb:27017");
sh.enableSharding("testdb");
sh.shardCollection("testdb.sample", { _id: "hashed" });
EOF