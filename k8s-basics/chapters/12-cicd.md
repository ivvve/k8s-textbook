# Chapter 12: CI/CD with Kubernetes

## Learning Objectives

By the end of this chapter, you will understand:
- CI/CD fundamentals and their importance in Kubernetes
- How to set up automated build and deployment pipelines
- GitOps principles and workflow
- Container image management and registry integration
- Blue-green and canary deployment strategies
- Pipeline security and best practices

## The Problem: Manual Deployments

Manual deployments in Kubernetes face several challenges:

1. **Inconsistency**: Different deployment commands each time
2. **Human error**: Typos, wrong configurations, forgotten steps
3. **Lack of auditability**: No record of who deployed what and when
4. **Slow feedback**: Manual testing and validation processes
5. **No rollback strategy**: Difficult to revert problematic deployments
6. **Environment drift**: Development and production become different

## CI/CD Overview

**Continuous Integration (CI)**: Automatically build, test, and validate code changes
**Continuous Deployment (CD)**: Automatically deploy validated changes to production

### CI/CD Pipeline Stages

1. **Source Control**: Code changes trigger the pipeline
2. **Build**: Compile code and create container images
3. **Test**: Run automated tests (unit, integration, security)
4. **Package**: Create deployment artifacts
5. **Deploy**: Deploy to staging/production environments
6. **Monitor**: Validate deployment success and performance

## GitOps Principles

**GitOps** is a deployment methodology where Git serves as the single source of truth for declarative infrastructure and applications.

### GitOps Workflow

```
Developer → Git Repository → CI Pipeline → Container Registry
                ↓
Git Repository (Config) → CD Agent → Kubernetes Cluster
```

### GitOps Benefits

1. **Version Control**: All changes are tracked in Git
2. **Rollback**: Easy rollback using Git history
3. **Audit Trail**: Complete deployment history
4. **Security**: No direct cluster access needed
5. **Consistency**: Same process for all environments

## Setting Up a Simple CI/CD Pipeline

Let's create a complete CI/CD pipeline for our Todo application using GitHub Actions.

### Step 1: Repository Structure

Create the following directory structure:

```
todo-app/
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── cd.yml
├── app/
│   ├── frontend/
│   │   ├── Dockerfile
│   │   └── src/
│   └── backend/
│       ├── Dockerfile
│       ├── package.json
│       └── src/
├── k8s/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── frontend.yaml
│   │   ├── backend.yaml
│   │   └── database.yaml
│   ├── overlays/
│   │   ├── development/
│   │   ├── staging/
│   │   └── production/
└── scripts/
    ├── build.sh
    └── deploy.sh
```

### Step 2: Containerize the Application

Create `app/backend/Dockerfile`:

```dockerfile
# Backend Dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY src/ ./src/

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start application
CMD ["node", "src/server.js"]
```

Create `app/frontend/Dockerfile`:

```dockerfile
# Multi-stage build for React frontend
FROM node:18-alpine as build

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY src/ ./src/
COPY public/ ./public/
RUN npm run build

# Production stage with nginx
FROM nginx:1.21-alpine

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy built application
COPY --from=build /app/build /usr/share/nginx/html

# Create non-root user
RUN addgroup -g 1001 -S nginx
RUN adduser -S nginx -u 1001
USER nginx

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

### Step 3: Kubernetes Manifests with Kustomize

Create `k8s/base/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - frontend.yaml
  - backend.yaml
  - database.yaml

commonLabels:
  app: todoapp
  version: v1.0.0

images:
  - name: todo-frontend
    newTag: latest
  - name: todo-backend
    newTag: latest
```

Create `k8s/base/backend.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      component: backend
  template:
    metadata:
      labels:
        component: backend
    spec:
      containers:
      - name: backend
        image: todo-backend:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: DB_HOST
          value: "mysql-service"
        - name: REDIS_HOST
          value: "redis-service"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"

---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  selector:
    component: backend
  ports:
  - port: 80
    targetPort: 3000
```

Create `k8s/overlays/production/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: todo-production

resources:
  - ../../base

patchesStrategicMerge:
  - production-config.yaml

replicas:
  - name: backend
    count: 5
  - name: frontend
    count: 3

images:
  - name: todo-frontend
    newTag: v1.2.3
  - name: todo-backend
    newTag: v1.2.3
```

### Step 4: CI Pipeline (Build and Test)

Create `.github/workflows/ci.yml`:

```yaml
name: CI Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
        cache-dependency-path: app/backend/package-lock.json

    - name: Install dependencies
      run: |
        cd app/backend
        npm ci

    - name: Run linting
      run: |
        cd app/backend
        npm run lint

    - name: Run unit tests
      run: |
        cd app/backend
        npm test

    - name: Run integration tests
      run: |
        cd app/backend
        npm run test:integration

  security-scan:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Run security audit
      run: |
        cd app/backend
        npm audit --audit-level high

    - name: Scan for secrets
      uses: trufflesecurity/trufflehog@main
      with:
        path: ./
        base: main
        head: HEAD

  build:
    needs: [test, security-scan]
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta-backend
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-backend
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=sha,prefix={{branch}}-
          type=raw,value=latest,enable={{is_default_branch}}

    - name: Build and push backend image
      uses: docker/build-push-action@v5
      with:
        context: ./app/backend
        push: true
        tags: ${{ steps.meta-backend.outputs.tags }}
        labels: ${{ steps.meta-backend.outputs.labels }}

    - name: Extract metadata (frontend)
      id: meta-frontend
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-frontend
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=sha,prefix={{branch}}-
          type=raw,value=latest,enable={{is_default_branch}}

    - name: Build and push frontend image
      uses: docker/build-push-action@v5
      with:
        context: ./app/frontend
        push: true
        tags: ${{ steps.meta-frontend.outputs.tags }}
        labels: ${{ steps.meta-frontend.outputs.labels }}

  kubernetes-validate:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Kustomize
      run: |
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/

    - name: Validate Kubernetes manifests
      run: |
        kustomize build k8s/overlays/production > /tmp/manifests.yaml
        kubectl --dry-run=client apply -f /tmp/manifests.yaml

    - name: Security scan Kubernetes manifests
      uses: azure/k8s-lint@v1
      with:
        manifests: |
          k8s/base/*.yaml
          k8s/overlays/production/*.yaml
```

### Step 5: CD Pipeline (Deploy)

Create `.github/workflows/cd.yml`:

```yaml
name: CD Pipeline

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  deploy-staging:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: staging
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: 'v1.28.0'

    - name: Configure kubectl
      run: |
        mkdir -p $HOME/.kube
        echo "${{ secrets.KUBECONFIG_STAGING }}" | base64 -d > $HOME/.kube/config

    - name: Setup Kustomize
      run: |
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/

    - name: Deploy to staging
      run: |
        cd k8s/overlays/staging
        kustomize edit set image todo-backend=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-backend:${{ github.sha }}
        kustomize edit set image todo-frontend=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-frontend:${{ github.sha }}
        kustomize build . | kubectl apply -f -

    - name: Wait for deployment
      run: |
        kubectl rollout status deployment/backend -n todo-staging --timeout=300s
        kubectl rollout status deployment/frontend -n todo-staging --timeout=300s

    - name: Run smoke tests
      run: |
        kubectl run smoke-test --image=curlimages/curl:latest --rm -i --restart=Never \
          -- curl -f http://frontend-service.todo-staging/health

  deploy-production:
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    environment: production
    needs: []
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: 'v1.28.0'

    - name: Configure kubectl
      run: |
        mkdir -p $HOME/.kube
        echo "${{ secrets.KUBECONFIG_PRODUCTION }}" | base64 -d > $HOME/.kube/config

    - name: Setup Kustomize
      run: |
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/

    - name: Extract version
      id: version
      run: echo "VERSION=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT

    - name: Blue-Green Deployment
      run: |
        # Deploy to green environment first
        cd k8s/overlays/production
        kustomize edit set image todo-backend=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-backend:${{ steps.version.outputs.VERSION }}
        kustomize edit set image todo-frontend=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-frontend:${{ steps.version.outputs.VERSION }}
        
        # Add green suffix to deployments
        kustomize edit set namesuffix -- -green
        kustomize build . | kubectl apply -f -

    - name: Wait for green deployment
      run: |
        kubectl rollout status deployment/backend-green -n todo-production --timeout=300s
        kubectl rollout status deployment/frontend-green -n todo-production --timeout=300s

    - name: Run production tests
      run: |
        # Test green environment
        kubectl run prod-test --image=curlimages/curl:latest --rm -i --restart=Never \
          -- curl -f http://frontend-service-green.todo-production/api/health

    - name: Switch traffic to green
      run: |
        # Update services to point to green deployment
        kubectl patch service frontend-service -n todo-production \
          -p '{"spec":{"selector":{"component":"frontend","app":"todoapp","kustomize.toolkit.fluxcd.io/name":"production","kustomize.toolkit.fluxcd.io/namespace":"todo-production"}}}'
        kubectl patch service backend-service -n todo-production \
          -p '{"spec":{"selector":{"component":"backend","app":"todoapp","kustomize.toolkit.fluxcd.io/name":"production","kustomize.toolkit.fluxcd.io/namespace":"todo-production"}}}'

    - name: Cleanup old deployment
      run: |
        # Remove blue deployment after successful green deployment
        sleep 60  # Wait for traffic to stabilize
        kubectl delete deployment backend frontend -n todo-production --ignore-not-found=true
        
        # Rename green to blue for next deployment
        kubectl patch deployment backend-green -n todo-production \
          -p '{"metadata":{"name":"backend"}}'
        kubectl patch deployment frontend-green -n todo-production \
          -p '{"metadata":{"name":"frontend"}}'
```

### Step 6: Local Development Pipeline

Create `scripts/build.sh`:

```bash
#!/bin/bash

set -e

echo "Building Todo Application..."

# Build backend
echo "Building backend..."
cd app/backend
docker build -t todo-backend:dev .
cd ../..

# Build frontend
echo "Building frontend..."
cd app/frontend
docker build -t todo-frontend:dev .
cd ../..

echo "Build completed successfully!"

# Optional: Run tests
if [ "$1" = "--test" ]; then
    echo "Running tests..."
    
    # Start test database
    docker run -d --name test-mysql \
        -e MYSQL_ROOT_PASSWORD=testpass \
        -e MYSQL_DATABASE=testdb \
        -p 3307:3306 \
        mysql:8.0
    
    # Wait for database
    sleep 30
    
    # Run backend tests
    cd app/backend
    npm test
    cd ../..
    
    # Cleanup
    docker stop test-mysql
    docker rm test-mysql
    
    echo "Tests completed!"
fi
```

Create `scripts/deploy.sh`:

```bash
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
```

## Advanced Deployment Strategies

### 1. Canary Deployment

Create `k8s/overlays/canary/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: todo-production

resources:
  - ../../base

patchesStrategicMerge:
  - canary-patch.yaml

namePrefix: canary-

replicas:
  - name: backend
    count: 1  # Small canary deployment
  - name: frontend
    count: 1

images:
  - name: todo-backend
    newTag: v1.3.0-beta
  - name: todo-frontend
    newTag: v1.3.0-beta
```

Create canary service configuration:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-canary
spec:
  selector:
    component: backend
    version: canary
  ports:
  - port: 80
    targetPort: 3000

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: canary-ingress
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"  # 10% traffic
spec:
  rules:
  - host: todoapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backend-canary
            port:
              number: 80
```

### 2. Feature Flag Deployment

Create feature flag configuration:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: feature-flags
data:
  features.json: |
    {
      "newUI": {
        "enabled": true,
        "rollout": 50,
        "conditions": {
          "userAgent": "Chrome"
        }
      },
      "betaFeatures": {
        "enabled": false,
        "rollout": 0
      },
      "maintenanceMode": {
        "enabled": false,
        "message": "System maintenance in progress"
      }
    }
```

## GitOps with ArgoCD

### ArgoCD Installation

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for deployment
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### ArgoCD Application Configuration

Create `argocd/application.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: todoapp-production
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/todo-app
    targetRevision: HEAD
    path: k8s/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: todo-production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
  revisionHistoryLimit: 10
```

### Multi-Environment ArgoCD Setup

Create `argocd/app-of-apps.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: todoapp-environments
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/todo-app
    targetRevision: HEAD
    path: argocd/environments
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true

---
# Development environment
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: todoapp-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/todo-app
    targetRevision: develop
    path: k8s/overlays/development
  destination:
    server: https://kubernetes.default.svc
    namespace: todo-development
  syncPolicy:
    automated:
      prune: true
      selfHeal: true

---
# Staging environment
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: todoapp-staging
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/todo-app
    targetRevision: main
    path: k8s/overlays/staging
  destination:
    server: https://kubernetes.default.svc
    namespace: todo-staging
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Pipeline Security Best Practices

### 1. Secret Management

```yaml
# Use external secret management
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "example-role"

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: mysql-secret
    creationPolicy: Owner
  data:
  - secretKey: password
    remoteRef:
      key: database
      property: password
```

### 2. Image Security Scanning

Add to CI pipeline:

```yaml
- name: Scan container images
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: '${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-backend:${{ github.sha }}'
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Upload Trivy scan results
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: 'trivy-results.sarif'
```

### 3. RBAC for CI/CD

Create service account with minimal permissions:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cicd-deployer
  namespace: todo-production

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: todo-production
  name: deployer-role
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["services", "configmaps", "secrets"]
  verbs: ["get", "list", "create", "update", "patch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployer-binding
  namespace: todo-production
subjects:
- kind: ServiceAccount
  name: cicd-deployer
  namespace: todo-production
roleRef:
  kind: Role
  name: deployer-role
  apiGroup: rbac.authorization.k8s.io
```

## Monitoring and Observability

### 1. Pipeline Monitoring

Create `monitoring/pipeline-dashboard.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: pipeline-metrics
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
```

### 2. Deployment Notifications

Add to CD pipeline:

```yaml
- name: Notify deployment success
  if: success()
  uses: 8398a7/action-slack@v3
  with:
    status: success
    text: 'Deployment to production completed successfully!'
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

- name: Notify deployment failure
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: failure
    text: 'Production deployment failed!'
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

## Rollback Strategies

### 1. Automated Rollback

```yaml
- name: Health check after deployment
  run: |
    # Wait for pods to be ready
    kubectl wait --for=condition=ready pod -l app=todoapp -n todo-production --timeout=300s
    
    # Run health checks
    HEALTH_CHECK=$(kubectl run health-check --image=curlimages/curl:latest --rm -i --restart=Never \
      -- curl -s -o /dev/null -w "%{http_code}" http://frontend-service.todo-production/health)
    
    if [ "$HEALTH_CHECK" != "200" ]; then
      echo "Health check failed, rolling back..."
      kubectl rollout undo deployment/backend -n todo-production
      kubectl rollout undo deployment/frontend -n todo-production
      exit 1
    fi
```

### 2. Manual Rollback Commands

```bash
# List rollout history
kubectl rollout history deployment/backend -n todo-production

# Rollback to previous version
kubectl rollout undo deployment/backend -n todo-production

# Rollback to specific revision
kubectl rollout undo deployment/backend --to-revision=2 -n todo-production

# Check rollback status
kubectl rollout status deployment/backend -n todo-production
```

## Testing Strategies

### 1. Unit Tests in Pipeline

```yaml
- name: Run unit tests with coverage
  run: |
    cd app/backend
    npm test -- --coverage --watchAll=false
    
- name: Upload coverage reports
  uses: codecov/codecov-action@v4
  with:
    file: ./app/backend/coverage/lcov.info
    flags: backend
```

### 2. Integration Tests

```yaml
- name: Start test environment
  run: |
    docker-compose -f docker-compose.test.yml up -d
    sleep 30

- name: Run integration tests
  run: |
    cd app/backend
    npm run test:integration

- name: Cleanup test environment
  if: always()
  run: |
    docker-compose -f docker-compose.test.yml down
```

### 3. End-to-End Tests

```yaml
- name: Deploy to test environment
  run: |
    kubectl create namespace test-env --dry-run=client -o yaml | kubectl apply -f -
    kustomize build k8s/overlays/test | kubectl apply -f -

- name: Run E2E tests
  run: |
    kubectl wait --for=condition=ready pod -l app=todoapp -n test-env --timeout=300s
    npm run test:e2e

- name: Cleanup test environment
  if: always()
  run: |
    kubectl delete namespace test-env
```

## Best Practices

### 1. Branch Strategy

```
main (production)
├── develop (staging)
├── feature/new-ui
├── hotfix/security-patch
└── release/v1.3.0
```

### 2. Semantic Versioning

Use semantic versioning for releases:
- `v1.0.0` - Major release
- `v1.1.0` - Minor release (new features)
- `v1.1.1` - Patch release (bug fixes)

### 3. Environment Parity

Ensure all environments are as similar as possible:
- Same container images
- Same configuration structure
- Same resource limits (scaled appropriately)

### 4. Pipeline as Code

Store all pipeline configurations in Git:
- CI/CD workflows
- Infrastructure as Code
- Configuration files
- Deployment scripts

## Troubleshooting CI/CD Issues

### Common Problems

#### 1. Image Pull Failures

```bash
# Check image exists
docker pull ghcr.io/your-org/todo-backend:latest

# Check registry credentials
kubectl get secret regcred -o yaml

# Check pod events
kubectl describe pod <pod-name>
```

#### 2. Deployment Timeouts

```bash
# Increase timeout values
kubectl rollout status deployment/backend --timeout=600s

# Check resource constraints
kubectl describe node
kubectl top pods
```

#### 3. Configuration Issues

```bash
# Validate manifests
kubectl apply --dry-run=client -f manifests.yaml

# Check ConfigMap/Secret updates
kubectl get configmap app-config -o yaml
```

## Key Takeaways

1. **Automation reduces errors** - Consistent, repeatable deployments
2. **GitOps provides auditability** - All changes tracked in Git
3. **Security is paramount** - Scan images, manage secrets properly
4. **Test everything** - Unit, integration, and E2E tests
5. **Monitor deployments** - Health checks and automated rollbacks
6. **Progressive delivery** - Blue-green, canary, and feature flags
7. **Environment parity** - Keep environments consistent

## Hands-On Exercises

### Exercise 1: Basic CI/CD Pipeline

1. Set up a GitHub repository with the Todo application
2. Create CI pipeline with build and test stages
3. Deploy to a staging environment automatically

### Exercise 2: GitOps with ArgoCD

1. Install ArgoCD in your cluster
2. Set up GitOps deployment for multiple environments
3. Test the sync and self-healing capabilities

### Exercise 3: Advanced Deployment Strategy

1. Implement blue-green deployment
2. Set up canary deployment with traffic splitting
3. Create automated rollback on health check failure

## Cleaning Up

```bash
# Delete ArgoCD
kubectl delete namespace argocd

# Delete test applications
kubectl delete namespace todo-development todo-staging todo-production

# Clean up container images
docker system prune -a
```

## Commands Reference

| Command | Purpose |
|---------|---------|
| `kubectl apply -k <overlay-path>` | Apply Kustomize overlay |
| `kubectl rollout status deployment/<name>` | Check deployment status |
| `kubectl rollout undo deployment/<name>` | Rollback deployment |
| `kustomize build <path>` | Build Kustomize manifests |
| `docker build -t <image>:<tag> .` | Build container image |
| `kubectl create secret docker-registry <name>` | Create registry secret |
| `kubectl logs -f deployment/<name>` | Follow deployment logs |

---

**Next Chapter**: [Debugging and Troubleshooting](../13-debugging/) - Learn comprehensive debugging techniques and problem-solving strategies in Kubernetes.