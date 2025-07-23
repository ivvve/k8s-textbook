#!/bin/bash

# Blue-Green Deployment Script
set -e

NAMESPACE=${1:-production}
APP_NAME=${2:-webapp}
NEW_VERSION=${3:-v2.0.0}

echo "Starting blue-green deployment for $APP_NAME to version $NEW_VERSION"

# Deploy green environment
echo "Deploying green environment..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}-green
  namespace: ${NAMESPACE}
  labels:
    app: ${APP_NAME}
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ${APP_NAME}
      version: green
  template:
    metadata:
      labels:
        app: ${APP_NAME}
        version: green
    spec:
      containers:
      - name: ${APP_NAME}
        image: ${APP_NAME}:${NEW_VERSION}
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
EOF

# Wait for green deployment to be ready
echo "Waiting for green deployment to be ready..."
kubectl rollout status deployment/${APP_NAME}-green -n ${NAMESPACE} --timeout=300s

# Run health checks on green environment
echo "Running health checks on green environment..."
kubectl run health-check-${RANDOM} --image=curlimages/curl --rm -i --restart=Never -n ${NAMESPACE} -- \
  curl -f http://${APP_NAME}-green-service.${NAMESPACE}.svc.cluster.local/health

# Switch traffic to green
echo "Switching traffic to green environment..."
kubectl patch service ${APP_NAME}-service -n ${NAMESPACE} -p '{"spec":{"selector":{"version":"green"}}}'

# Wait and monitor
echo "Monitoring green environment for 5 minutes..."
sleep 300

# Health check after traffic switch
if kubectl run final-health-check-${RANDOM} --image=curlimages/curl --rm -i --restart=Never -n ${NAMESPACE} -- \
   curl -f http://${APP_NAME}-service.${NAMESPACE}.svc.cluster.local/health; then
  echo "Green environment is healthy, cleaning up blue environment..."
  kubectl delete deployment ${APP_NAME}-blue -n ${NAMESPACE} || true
  
  # Rename green to blue for next deployment
  kubectl patch deployment ${APP_NAME}-green -n ${NAMESPACE} --type='merge' -p='{"metadata":{"name":"${APP_NAME}-blue"}}'
  
  echo "Blue-green deployment completed successfully!"
else
  echo "Health check failed, rolling back to blue environment..."
  kubectl patch service ${APP_NAME}-service -n ${NAMESPACE} -p '{"spec":{"selector":{"version":"blue"}}}'
  kubectl delete deployment ${APP_NAME}-green -n ${NAMESPACE}
  exit 1
fi