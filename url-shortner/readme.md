To build a URL shortener service on your MacBook using a local Kubernetes cluster with `kind`, Helm for deployment, and Kong as the ingress controller, I'll outline the system components, their roles, and provide the necessary Helm charts to deploy them. The URL shortener service will include a web application, a database for storing URL mappings, and an ingress controller to manage external traffic. I'll use Redis as the database for simplicity and speed, and a basic Node.js application for the URL shortener logic. Below, I’ll define the components, provide the Helm chart structure, and include instructions for setting up the cluster and deploying the application.

### System Design Overview

**Components in the Kubernetes Cluster:**
1. **Kind Cluster**: A local Kubernetes cluster created using `kind` to simulate a production-like environment.
2. **Kong Ingress Controller**: Handles external HTTP/HTTPS traffic, routing requests to the URL shortener service.
3. **URL Shortener Application**: A Node.js application that handles URL shortening logic (create short URLs, redirect to original URLs).
4. **Redis**: An in-memory key-value store to persist the mapping of short URLs to original URLs.
5. **Monitoring (Optional)**: Prometheus and Grafana for monitoring the application (included for a robust PoC but can be skipped if not needed).

**Architecture**:
- Users send HTTP requests (e.g., POST to create a short URL, GET to redirect) to the Kong ingress controller.
- Kong routes requests to the URL shortener application.
- The application interacts with Redis to store or retrieve URL mappings.
- Prometheus and Grafana (optional) monitor the application’s performance and health.

**Assumptions**:
- You have `kind`, `kubectl`, `helm`, and `docker` installed on your MacBook.
- The URL shortener will support basic functionality: creating short URLs and redirecting to the original URL.
- The service will be accessible locally via `http` (no HTTPS for simplicity in a local PoC).
- The Node.js application uses Express and Redis client libraries.

### Kubernetes Components

1. **Namespace**: A dedicated namespace (`url-shortener`) to isolate resources.
2. **Deployments**:
   - **URL Shortener App**: Runs the Node.js application with multiple replicas for high availability.
   - **Redis**: Runs a single Redis instance for storing URL mappings.
   - **Kong**: Deploys the Kong ingress controller.
   - **Prometheus/Grafana** (optional): For monitoring.
3. **Services**:
   - **url-shortener-service**: ClusterIP service for the Node.js app.
   - **redis-service**: ClusterIP service for Redis.
   - **kong-service**: Exposes Kong to handle external traffic.
4. **Ingress**: A Kong-managed Ingress resource to route traffic to the URL shortener service.
5. **ConfigMaps/Secrets**: Store configuration (e.g., Redis connection details).
6. **PersistentVolumeClaim** (optional): For Redis data persistence (not strictly necessary for a PoC but included for completeness).

### Helm Chart Structure

We’ll create a custom Helm chart for the URL shortener service and use existing Helm charts for Kong, Redis, and monitoring. The custom chart will include the Node.js application deployment.

**Directory Structure**:
```
url-shortener/
├── charts/
│   ├── kong/
│   ├── redis/
│   ├── prometheus/ (optional)
│   ├── grafana/ (optional)
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
├── Chart.yaml
├── values.yaml
```

### Step-by-Step Setup

#### 1. Create the Kind Cluster
Create a `kind` cluster with a configuration that enables Ingress support.

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
```

**Command**:
```bash
kind create cluster --name url-shortener --config kind-config.yaml
```

This creates a cluster named `url-shortener` with ports 80 and 443 mapped to the host, enabling Ingress access.

#### 2. Install Helm Charts for Dependencies

Add Helm repositories:
```bash
helm repo add kong https://charts.konghq.com
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

**Install Kong Ingress Controller**:
```bash
helm install kong kong/kong --namespace url-shortener --create-namespace \
  --set ingressController.install=true \
  --set admin.enabled=true \
  --set admin.http.enabled=true \
  --set admin.http.service.port=8001 \
  --set proxy.enabled=true \
  --set proxy.http.enabled=true \
  --set proxy.http.service.port=80
```

**Install Redis**:
```bash
helm install redis bitnami/redis --namespace url-shortener \
  --set architecture=standalone \
  --set auth.enabled=false
```

**Install Prometheus and Grafana (Optional)**:
```bash
helm install prometheus prometheus-community/kube-prometheus-stack --namespace url-shortener \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
helm install grafana grafana/grafana --namespace url-shortener \
  --set admin.password=admin
```

#### 3. Create the URL Shortener Helm Chart

**Node.js Application Code**:
Below is a simple Node.js application for the URL shortener.

```javascript
const express = require('express');
const redis = require('redis');
const crypto = require('crypto');
const app = express();
app.use(express.json());

const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://redis-service:6379'
});
redisClient.connect().catch(console.error);

app.post('/shorten', async (req, res) => {
  const { url } = req.body;
  if (!url) return res.status(400).json({ error: 'URL is required' });
  const shortId = crypto.randomBytes(4).toString('hex');
  await redisClient.set(shortId, url);
  res.json({ shortUrl: `http://localhost/${shortId}` });
});

app.get('/:shortId', async (req, res) => {
  const { shortId } = req.params;
  try {
    const url = await redisClient.get(shortId);
    if (url) {
      res.redirect(url);
    } else {
      res.status(404).json({ error: 'Short URL not found' });
    }
  } catch (err) {
    console.error('Redis error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.listen(3000, () => console.log('Server running on port 3000'));
```

**Dockerfile for the Application**:
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install express redis
COPY app.js ./
EXPOSE 3000
CMD ["node", "app.js"]
```

**Build and Push the Docker Image**:
```bash
docker build -t url-shortener-app:latest .
kind load docker-image url-shortener-app:latest --name url-shortener
```

**Helm Chart for URL Shortener**:
Create the Helm chart structure:
```bash
helm create url-shortener
```

Modify the Helm chart files as follows:

```yaml
apiVersion: v2
name: url-shortener
description: A Helm chart for URL Shortener service
version: 0.1.0
appVersion: "1.0"
```

<xaiArtifact artifact_id="afb466af-5ed2-42e3-af33-abf272c37ba8" artifact_version_id="2e5928bc-c893-4f0a-97d4-83db22db33cd" title="values.yaml" contentType="text/yaml">
replicaCount: 2

image:
  repository: url-shortener-app
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 3000

ingress:
  enabled: true
  hosts:
    - host: localhost
      paths:
        - path: /
          pathType: Prefix

redis:
  host: redis-service
  port: 6379
</xaiArtifact>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-url-shortener
  namespace: {{ .Release.Namespace }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}-url-shortener
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}-url-shortener
    spec:
      containers:
      - name: url-shortener
        image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - containerPort: 3000
        env:
        - name: REDIS_URL
          value: redis://{{ .Values.redis.host }}:{{ .Values.redis.port }}
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-url-shortener
  namespace: {{ .Release.Namespace }}
spec:
  selector:
    app: {{ .Release.Name }}-url-shortener
  ports:
  - port: {{ .Values.service.port }}
    targetPort: 3000
  type: {{ .Values.service.type }}
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Release.Name }}-url-shortener
  namespace: {{ .Release.Namespace }}
  annotations:
    konghq.com/strip-path: "false"
spec:
  ingressClassName: kong
  rules:
  {{- range .Values.ingress.hosts }}
  - host: {{ .host }}
    http:
      paths:
      {{- range .paths }}
      - path: {{ .path }}
        pathType: {{ .pathType }}
        backend:
          service:
            name: {{ $.Release.Name }}-url-shortener
            port:
              number: {{ $.Values.service.port }}
      {{- end }}
  {{- end }}
```

#### 4. Deploy the URL Shortener Chart
```bash
helm install url-shortener ./url-shortener --namespace url-shortener
```

#### 5. Test the Application
- Create a short URL:
  ```bash
  curl -X POST http://localhost/shorten -H "Content-Type: application/json" -d '{"url":"https://example.com"}'
  ```
  Expected response: `{"shortUrl":"http://localhost/<shortId>"}`

- Access the short URL:
  ```bash
  curl http://localhost/<shortId>
  ```
  This should redirect to `https://example.com`.

#### 6. Access Monitoring (Optional)
- Prometheus: Access via port-forwarding:
  ```bash
  kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n url-shortener 9090:9090
  ```
  Open `http://localhost:9090`.

- Grafana: Get the admin password and port-forward:
  ```bash
  kubectl get secret grafana -n url-shortener -o jsonpath="{.data.admin-password}" | base64 --decode
  kubectl port-forward svc/grafana -n url-shortener 3000:80
  ```
  Open `http://localhost:3000` and log in with `admin/<password>`.

### Notes
- **Redis**: For a PoC, `auth.enabled=false` is used for simplicity. In production, enable authentication and use Secrets for credentials.
- **Kong**: Configured to use HTTP on port 80. For production, enable HTTPS and configure TLS.
- **Monitoring**: Prometheus and Grafana are optional but recommended for observing application metrics.
- **Persistence**: Redis persistence is disabled for simplicity. Add a PersistentVolumeClaim in the Redis Helm values for persistence.
- **Scaling**: The `replicaCount` is set to 2 for the URL shortener app. Adjust based on load testing.
- **Local Access**: The Ingress is configured for `localhost`. For external access, use a local tunnel (e.g., `ngrok`) or modify the Ingress host.

### Cleanup
To delete the cluster:
```bash
kind delete cluster --name url-shortener
```

This setup provides a fully functional URL shortener service deployed on a local Kubernetes cluster using `kind`, with Kong as the ingress controller and Helm for deployment management. Let me know if you need further customization or additional components!


### re create the kong

```
helm install kong kong/kong --namespace url-shortener --create-namespace -f kong-values.yaml
```



```
helm install kong kong/kong --namespace url-shortener --create-namespace -f kong-values.yaml
```