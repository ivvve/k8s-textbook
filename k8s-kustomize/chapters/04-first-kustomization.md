# Chapter 4: Your First Kustomization

## Learning Objectives

By the end of this chapter, you will be able to:
- Create a complete base configuration from scratch
- Build and deploy a simple web application using Kustomize
- Understand the generated resources and their relationships
- Deploy and test applications in minikube
- Debug common issues in your first kustomization

## Prerequisites

Before starting this hands-on chapter:
- Complete environment setup from Chapter 2
- Have minikube running: `minikube status`
- Understand basic concepts from Chapter 3

## Project Overview

We'll create a simple nginx web application with the following components:
- **Deployment**: Runs nginx containers
- **Service**: Exposes the application internally
- **ConfigMap**: Stores custom nginx configuration
- **Ingress**: Provides external access

### Project Structure

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

## Step 1: Setting Up the Project

Create the project directory structure:

```bash
# Navigate to your workspace
cd ~/kustomize-workspace

# Create project structure
mkdir -p nginx-webapp/{base,overlays/development}
cd nginx-webapp
```

## Step 2: Creating Base Configuration

Let's start by creating the base Kubernetes resources.

### 2.1 Deployment Resource

Create `base/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-webapp
  labels:
    app: nginx-webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-webapp
  template:
    metadata:
      labels:
        app: nginx-webapp
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
          name: http
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
          readOnly: true
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config
```

### 2.2 Service Resource

Create `base/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-webapp
  labels:
    app: nginx-webapp
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  selector:
    app: nginx-webapp
```

### 2.3 ConfigMap Resource

Create `base/configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  labels:
    app: nginx-webapp
data:
  default.conf: |
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
        
        # Basic security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
    }
```

### 2.4 Ingress Resource

Create `base/ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-webapp
  labels:
    app: nginx-webapp
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: nginx.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-webapp
            port:
              number: 80
```

### 2.5 Base Kustomization File

Create `base/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: nginx-webapp-base

# List of resource files to include
resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
  - ingress.yaml

# Common labels applied to all resources
commonLabels:
  app: nginx-webapp
  component: web-server
  managed-by: kustomize

# Common annotations applied to all resources
commonAnnotations:
  app.kubernetes.io/version: "1.0.0"
  app.kubernetes.io/managed-by: kustomize

# Images (can be overridden in overlays)
images:
  - name: nginx
    newTag: "1.21"
```

## Step 3: Building and Validating Base Configuration

Let's build and validate our base configuration:

```bash
# Navigate to the base directory
cd base

# Build the configuration
kustomize build .

# Validate the output
kustomize build . | kubectl apply --dry-run=client -f -
```

You should see output showing all four resources with the applied labels and annotations.

### Understanding the Generated Output

The `kustomize build` command processes our configuration and shows:

1. **Applied Labels**: All resources now have common labels
2. **Applied Annotations**: Common annotations added to metadata
3. **Resource Relationships**: ConfigMap referenced by Deployment
4. **Image Tags**: Explicit image tags specified

## Step 4: Deploying to minikube

Let's deploy our base configuration to minikube:

```bash
# Ensure minikube is running
minikube status

# Create a namespace for our application
kubectl create namespace nginx-webapp

# Apply the configuration
kustomize build . | kubectl apply -n nginx-webapp -f -

# Verify the deployment
kubectl get all -n nginx-webapp
```

### Expected Output

```bash
NAME                               READY   STATUS    RESTARTS   AGE
pod/nginx-webapp-xxxxxxxxx-xxxxx   1/1     Running   0          30s
pod/nginx-webapp-xxxxxxxxx-xxxxx   1/1     Running   0          30s

NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/nginx-webapp   ClusterIP   10.96.XXX.XXX   <none>        80/TCP    30s

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-webapp   2/2     2            2           30s

NAME                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-webapp-xxxxxxxxx   2         2         2       30s
```

### Testing the Application

```bash
# Test the service connectivity
kubectl port-forward -n nginx-webapp service/nginx-webapp 8080:80

# In another terminal, test the application
curl http://localhost:8080
curl http://localhost:8080/health

# Stop port forwarding with Ctrl+C
```

## Step 5: Creating Development Overlay

Now let's create a development overlay that customizes the base configuration.

### 5.1 Development Patches

Create `overlays/development/dev-patches.yaml`:

```yaml
# Patch for development-specific changes
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-webapp
spec:
  replicas: 1  # Reduce replicas for development
  template:
    spec:
      containers:
      - name: nginx
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"
        env:
        - name: ENVIRONMENT
          value: "development"

---
apiVersion: v1
kind: Service
metadata:
  name: nginx-webapp
spec:
  type: NodePort  # Change to NodePort for easy access
```

### 5.2 Development Kustomization

Create `overlays/development/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: nginx-webapp-development

# Reference the base configuration
resources:
  - ../../base

# Development-specific name prefix
namePrefix: dev-

# Development namespace
namespace: nginx-webapp-dev

# Additional labels for development
commonLabels:
  environment: development
  tier: development

# Additional annotations
commonAnnotations:
  deployment.kubernetes.io/revision: "1"
  environment: development

# Apply development patches
patches:
  - path: dev-patches.yaml

# ConfigMap generator for development-specific config
configMapGenerator:
  - name: dev-config
    literals:
      - ENVIRONMENT=development
      - DEBUG_MODE=true
      - LOG_LEVEL=debug

# Override image tag for development
images:
  - name: nginx
    newTag: "1.21-alpine"
```

## Step 6: Building and Deploying the Development Overlay

```bash
# Navigate to development overlay
cd ../overlays/development

# Build the development configuration
kustomize build .

# Create development namespace
kubectl create namespace nginx-webapp-dev

# Deploy to development environment
kustomize build . | kubectl apply -f -

# Verify deployment
kubectl get all -n nginx-webapp-dev
```

### Comparing Base vs Development

```bash
# Compare the outputs
echo "=== BASE CONFIGURATION ==="
kustomize build ../../base | head -20

echo "=== DEVELOPMENT CONFIGURATION ==="
kustomize build . | head -20
```

Notice the differences:
- Name prefix `dev-` added to all resources
- Different namespace
- Additional labels and annotations
- Modified resource limits
- Additional ConfigMap
- Different image tag

## Step 7: Understanding Generated Resources

Let's examine what Kustomize generated:

### 7.1 Resource Name Transformations

```bash
# Show resource names in base
kubectl get all -n nginx-webapp --show-labels

# Show resource names in development
kubectl get all -n nginx-webapp-dev --show-labels
```

### 7.2 ConfigMap Hash Generation

```bash
# Notice ConfigMap names have hash suffixes
kubectl get configmaps -n nginx-webapp-dev

# Examine the generated ConfigMap
kubectl describe configmap -n nginx-webapp-dev
```

Kustomize automatically adds hash suffixes to generated ConfigMaps and Secrets to trigger rolling updates when content changes.

### 7.3 Label and Annotation Propagation

```bash
# Examine labels on deployment
kubectl get deployment dev-nginx-webapp -n nginx-webapp-dev -o yaml | grep -A 10 labels:

# Examine annotations
kubectl get deployment dev-nginx-webapp -n nginx-webapp-dev -o yaml | grep -A 5 annotations:
```

## Step 8: Testing and Verification

### 8.1 Application Functionality

```bash
# Test development deployment
kubectl port-forward -n nginx-webapp-dev service/dev-nginx-webapp 8081:80

# Test in another terminal
curl http://localhost:8081
curl http://localhost:8081/health
```

### 8.2 Resource Scaling

```bash
# Check replica count in base vs development
kubectl get deployment nginx-webapp -n nginx-webapp
kubectl get deployment dev-nginx-webapp -n nginx-webapp-dev

# Notice development has 1 replica, base has 2
```

### 8.3 Configuration Verification

```bash
# Check environment variables in development pods
kubectl exec -n nginx-webapp-dev deployment/dev-nginx-webapp -- env | grep ENVIRONMENT

# Check ConfigMap content
kubectl get configmap dev-config-* -n nginx-webapp-dev -o yaml
```

## Step 9: Debugging Common Issues

### Issue 1: Build Failures

```bash
# If kustomize build fails, check syntax
kustomize build . --dry-run

# Common issues:
# - Invalid YAML syntax
# - Missing resource files
# - Incorrect indentation
```

### Issue 2: Resource Not Found

```bash
# If resources aren't found:
# 1. Check file paths in kustomization.yaml
# 2. Verify file names match exactly
# 3. Check current working directory

ls -la  # Verify files exist
pwd     # Check current directory
```

### Issue 3: Failed to Apply

```bash
# If kubectl apply fails:
# 1. Check Kubernetes connectivity
kubectl cluster-info

# 2. Verify namespace exists
kubectl get namespaces

# 3. Check for validation errors
kustomize build . | kubectl apply --dry-run=server -f -
```

### Issue 4: ConfigMap Not Updating

```bash
# ConfigMaps with hash suffixes require deployment restart
kubectl rollout restart deployment/dev-nginx-webapp -n nginx-webapp-dev

# Or delete and recreate
kubectl delete -k .
kubectl apply -k .
```

## Step 10: Cleanup and Best Practices

### Cleanup Resources

```bash
# Clean up development environment
kubectl delete -k overlays/development/

# Clean up base environment
kubectl delete -k base/ -n nginx-webapp

# Remove namespaces
kubectl delete namespace nginx-webapp
kubectl delete namespace nginx-webapp-dev
```

### Best Practices Learned

1. **Start with Valid Resources**: Ensure base resources are valid Kubernetes YAML
2. **Use Meaningful Names**: Clear, descriptive names for files and resources
3. **Test Incrementally**: Build and validate frequently during development
4. **Organize Logically**: Keep related patches and configurations together
5. **Document Changes**: Use comments and annotations to explain customizations

## Advanced Exercise: Add Health Monitoring

Try extending your configuration with:

```yaml
# Add to base/deployment.yaml containers section
livenessProbe:
  httpGet:
    path: /health
    port: 80
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 5
```

## Chapter Summary

In this hands-on chapter, you've successfully:

1. **Created a complete base configuration** with Deployment, Service, ConfigMap, and Ingress
2. **Built and validated** configurations using Kustomize
3. **Deployed applications** to minikube and verified functionality
4. **Created environment-specific overlays** with patches and customizations
5. **Understood resource generation** including name transformations and hash suffixes
6. **Debugged common issues** and applied troubleshooting techniques

### Key Concepts Mastered

- **Base/overlay pattern**: Practical application of configuration reuse
- **Resource relationships**: How ConfigMaps, Deployments, and Services interact
- **Name transformations**: Prefixes, suffixes, and hash generation
- **Patch application**: Modifying resources without changing base files
- **Build and deploy workflow**: From source to running application

### Skills Developed

- Writing valid Kubernetes YAML for base configurations
- Creating effective kustomization.yaml files
- Applying patches and transformations
- Testing and validating deployments
- Debugging configuration issues

This foundation prepares you for more advanced Kustomize features including complex overlays, strategic merge patches, and CI/CD integration.

## Quick Reference

### Essential Commands
```bash
# Build configuration
kustomize build .
kustomize build overlays/development/

# Apply configuration  
kubectl apply -k .
kubectl apply -k overlays/development/

# Delete configuration
kubectl delete -k .

# Test and validate
kubectl apply --dry-run=client -k .
kubectl port-forward service/app-name 8080:80
```

### Directory Structure
```
project/
├── base/
│   ├── kustomization.yaml
│   └── *.yaml (resources)
└── overlays/
    └── environment/
        ├── kustomization.yaml
        └── patches.yaml
```

---

**Next**: [Chapter 5: Overlays and Environments](05-overlays-environments.md)

**Previous**: [Chapter 3: Basic Concepts and Architecture](03-basic-concepts.md)

**Quick Links**: [Table of Contents](../README.md) | [Examples](../examples/chapter-04/)