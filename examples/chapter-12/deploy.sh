#!/bin/bash

set -e

ENVIRONMENT=${1:-development}
IMAGE_TAG=${2:-latest}

echo "Deploying to $ENVIRONMENT environment with tag $IMAGE_TAG..."

# Setup kustomize
if ! command -v kustomize &> /dev/null; then
    echo "Installing kustomize..."
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    sudo mv kustomize /usr/local/bin/
fi

# Navigate to overlay directory
cd k8s/overlays/$ENVIRONMENT

# Update image tags
kustomize edit set image todo-backend:$IMAGE_TAG
kustomize edit set image todo-frontend:$IMAGE_TAG

# Deploy
echo "Applying manifests..."
kustomize build . | kubectl apply -f -

# Wait for rollout
echo "Waiting for deployment to complete..."
kubectl rollout status deployment/backend -n todo-$ENVIRONMENT --timeout=300s
kubectl rollout status deployment/frontend -n todo-$ENVIRONMENT --timeout=300s

echo "Deployment completed successfully!"

# Show status
kubectl get pods -n todo-$ENVIRONMENT
kubectl get services -n todo-$ENVIRONMENT