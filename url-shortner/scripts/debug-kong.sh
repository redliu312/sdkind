#!/bin/bash

NAMESPACE="url-shortener"
POD_NAME="kong-debug"
DEBUG_IMAGE="nicolaka/netshoot"

echo "🚀 Launching debug pod (detached)..."
kubectl run $POD_NAME \
  --image=$DEBUG_IMAGE \
  --restart=Never \
  --command -- sleep infinity \
  -n $NAMESPACE

echo ""
echo "⏳ Waiting for pod to be ready..."
kubectl wait --for=condition=Ready pod/$POD_NAME -n $NAMESPACE --timeout=30s

echo ""
echo "🔍 Getting Kong Pod IP..."
KONG_POD_IP=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/instance=kong -o jsonpath='{.items[0].status.podIP}')
echo "✅ Kong Pod IP: $KONG_POD_IP"

echo ""
echo "✅ You can now exec into the debug pod and run:"
echo "  nc -vz $KONG_POD_IP 80"
echo "  nc -vz $KONG_POD_IP 8000"
echo ""
echo "📥 To enter:"
echo "  kubectl exec -it $POD_NAME -n $NAMESPACE -- sh"
echo ""
echo "🧹 To delete after debug:"
echo "  kubectl delete pod $POD_NAME -n $NAMESPACE"