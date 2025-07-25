# Chapter 4 Examples: Your First Kustomization

This directory contains the complete working example from Chapter 4, demonstrating how to create your first Kustomize configuration.

## Project Structure

```
nginx-webapp/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── ingress.yaml
└── overlays/
    └── development/
        ├── kustomization.yaml
        └── dev-patches.yaml
```

## Quick Start

### Prerequisites
- minikube running
- kubectl configured
- kustomize installed

### Deploy Base Configuration

```bash
# Navigate to the example
cd nginx-webapp

# Build and view base configuration
kustomize build base/

# Deploy to minikube
kubectl create namespace nginx-webapp
kustomize build base/ | kubectl apply -n nginx-webapp -f -

# Test the deployment
kubectl port-forward -n nginx-webapp service/nginx-webapp 8080:80
curl http://localhost:8080
```

### Deploy Development Overlay

```bash
# Build and view development configuration
kustomize build overlays/development/

# Deploy development environment
kubectl apply -k overlays/development/

# Test the development deployment
kubectl port-forward -n nginx-webapp-dev service/dev-nginx-webapp 8081:80
curl http://localhost:8081
```

### Compare Configurations

```bash
# Compare base vs development
echo "=== BASE ==="
kustomize build base/ | grep -A 5 "kind: Deployment"

echo "=== DEVELOPMENT ==="
kustomize build overlays/development/ | grep -A 5 "kind: Deployment"
```

### Cleanup

```bash
# Remove development environment
kubectl delete -k overlays/development/

# Remove base environment
kubectl delete -k base/ -n nginx-webapp
kubectl delete namespace nginx-webapp
```

## Key Learning Points

1. **Base Configuration**: Complete, valid Kubernetes resources
2. **Overlay Pattern**: Environment-specific customizations
3. **Name Transformations**: Prefixes, suffixes, and namespaces
4. **Resource Patching**: Modifying base resources without editing
5. **ConfigMap Generation**: Dynamic configuration creation

## Files Overview

- `base/deployment.yaml`: nginx deployment with health checks
- `base/service.yaml`: ClusterIP service for internal access
- `base/configmap.yaml`: nginx configuration with custom settings
- `base/ingress.yaml`: External access configuration
- `base/kustomization.yaml`: Base kustomization settings
- `overlays/development/dev-patches.yaml`: Development-specific patches
- `overlays/development/kustomization.yaml`: Development overlay configuration