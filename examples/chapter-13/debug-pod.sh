#!/bin/bash

POD_NAME=$1
NAMESPACE=${2:-default}

if [ -z "$POD_NAME" ]; then
    echo "Usage: $0 <pod-name> [namespace]"
    exit 1
fi

echo "=== Debugging Pod: $POD_NAME ==="

echo "1. Basic Information:"
kubectl get pod $POD_NAME -n $NAMESPACE -o wide

echo -e "\n2. Pod Description:"
kubectl describe pod $POD_NAME -n $NAMESPACE

echo -e "\n3. Pod Events:"
kubectl get events --field-selector involvedObject.name=$POD_NAME -n $NAMESPACE

echo -e "\n4. Pod Logs:"
kubectl logs $POD_NAME -n $NAMESPACE --tail=50

echo -e "\n5. Previous Logs (if restarted):"
kubectl logs $POD_NAME -n $NAMESPACE --previous --tail=50 2>/dev/null || echo "No previous logs"

echo -e "\n6. Resource Usage:"
kubectl top pod $POD_NAME -n $NAMESPACE 2>/dev/null || echo "Metrics not available"

echo -e "\n7. Security Context:"
kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.securityContext}'

echo -e "\n8. Environment Variables:"
kubectl exec $POD_NAME -n $NAMESPACE -- env 2>/dev/null || echo "Cannot access pod"