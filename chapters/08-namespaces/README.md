# Chapter 8: Namespaces and Resource Management

## Learning Objectives

By the end of this chapter, you will understand:
- What namespaces are and why they're important
- How to create and manage namespaces
- Resource quotas and limits
- How to organize multi-environment setups
- Network policies and namespace isolation
- Best practices for namespace management

## The Problem: Resource Organization

As Kubernetes clusters grow, you need ways to:

1. **Organize resources**: Group related applications and services
2. **Isolate environments**: Separate development, staging, and production
3. **Control access**: Restrict who can access what resources
4. **Manage resources**: Set limits on CPU, memory, and storage usage
5. **Avoid naming conflicts**: Multiple teams using similar resource names

## What are Namespaces?

**Namespaces** provide a mechanism for isolating groups of resources within a single cluster. They're like virtual clusters within a physical cluster.

### Namespace Characteristics

1. **Logical separation**: Resources in different namespaces are isolated
2. **DNS scope**: Services get DNS names scoped to their namespace
3. **RBAC scope**: Permissions can be namespace-specific
4. **Resource quotas**: Limits can be applied per namespace
5. **Default isolation**: Some resources are namespace-scoped, others are cluster-scoped

### Default Namespaces

Kubernetes comes with several built-in namespaces:

```bash
# List all namespaces
kubectl get namespaces

# Or use the short form
kubectl get ns
```

Default namespaces:
- **default**: Default namespace for objects with no other namespace
- **kube-system**: System components created by Kubernetes
- **kube-public**: Readable by all users (including non-authenticated)
- **kube-node-lease**: Node heartbeat information

## Working with Namespaces

### Creating Namespaces

#### Method 1: Imperative Command

```bash
# Create namespace using kubectl
kubectl create namespace development
kubectl create namespace staging
kubectl create namespace production

# Verify creation
kubectl get namespaces
```

#### Method 2: YAML Declaration

Create `namespaces.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    environment: dev
    team: backend

---
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    environment: staging
    team: backend

---
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: prod
    team: backend
```

```bash
# Create namespaces from YAML
kubectl apply -f namespaces.yaml

# Check created namespaces with labels
kubectl get namespaces --show-labels
```

### Working with Resources in Namespaces

#### Specifying Namespace in Commands

```bash
# List pods in specific namespace
kubectl get pods -n development
kubectl get pods --namespace=staging

# List pods in all namespaces
kubectl get pods --all-namespaces
kubectl get pods -A  # Short form

# Create resource in specific namespace
kubectl run nginx --image=nginx:1.21 -n development

# Apply YAML to specific namespace
kubectl apply -f deployment.yaml -n staging
```

#### Setting Default Namespace

```bash
# View current context
kubectl config current-context

# Set default namespace for current context
kubectl config set-context --current --namespace=development

# Verify the change
kubectl config view --minify | grep namespace

# Now commands default to 'development' namespace
kubectl get pods  # Shows pods in development namespace
```

### Resource Names and DNS

Resources in different namespaces can have the same name:

```bash
# Create nginx deployment in multiple namespaces
kubectl create deployment nginx --image=nginx:1.21 -n development
kubectl create deployment nginx --image=nginx:1.21 -n staging
kubectl create deployment nginx --image=nginx:1.21 -n production

# List deployments across namespaces
kubectl get deployments -A
```

Services get DNS names scoped to their namespace:
- `service-name.namespace-name.svc.cluster.local`
- `nginx-service.development.svc.cluster.local`
- `nginx-service.staging.svc.cluster.local`

## Multi-Environment Setup Example

Let's create a complete multi-environment setup for a web application.

### Step 1: Create Environment Namespaces

Create `environments.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    environment: development
    purpose: webapp
    cost-center: engineering

---
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    environment: staging
    purpose: webapp
    cost-center: engineering

---
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: production
    purpose: webapp
    cost-center: engineering
```

```bash
# Create environments
kubectl apply -f environments.yaml

# Verify creation
kubectl get namespaces -l purpose=webapp
```

### Step 2: Deploy Application to Each Environment

Create `webapp-template.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app: webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: ENVIRONMENT
          value: "PLACEHOLDER"
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"

---
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  labels:
    app: webapp
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

Deploy to each environment with different configurations:

```bash
# Development environment (2 replicas)
sed 's/PLACEHOLDER/development/' webapp-template.yaml | kubectl apply -n development -f -

# Staging environment (3 replicas)
sed 's/replicas: 2/replicas: 3/' webapp-template.yaml | sed 's/PLACEHOLDER/staging/' | kubectl apply -n staging -f -

# Production environment (5 replicas)
sed 's/replicas: 2/replicas: 5/' webapp-template.yaml | sed 's/PLACEHOLDER/production/' | kubectl apply -n production -f -

# Verify deployments
kubectl get deployments -A -l app=webapp
kubectl get services -A -l app=webapp
```

### Step 3: Environment-Specific ConfigMaps

Create environment-specific configuration:

```bash
# Development config
kubectl create configmap webapp-config \
  --from-literal=database_host=dev-db.development.svc.cluster.local \
  --from-literal=log_level=debug \
  --from-literal=cache_enabled=false \
  -n development

# Staging config
kubectl create configmap webapp-config \
  --from-literal=database_host=staging-db.staging.svc.cluster.local \
  --from-literal=log_level=info \
  --from-literal=cache_enabled=true \
  -n staging

# Production config
kubectl create configmap webapp-config \
  --from-literal=database_host=prod-db.production.svc.cluster.local \
  --from-literal=log_level=warn \
  --from-literal=cache_enabled=true \
  -n production

# Verify configs
kubectl get configmaps -A
```

## Resource Quotas

**Resource Quotas** provide constraints that limit aggregate resource consumption per namespace.

### Creating Resource Quotas

Create `resource-quotas.yaml`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: development-quota
  namespace: development
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    pods: "10"
    persistentvolumeclaims: "5"
    services: "10"

---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: staging-quota
  namespace: staging
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
    persistentvolumeclaims: "10"
    services: "15"

---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "8"
    requests.memory: 16Gi
    limits.cpu: "16"
    limits.memory: 32Gi
    pods: "50"
    persistentvolumeclaims: "20"
    services: "25"
```

```bash
# Apply resource quotas
kubectl apply -f resource-quotas.yaml

# Check quota status
kubectl get resourcequota -A
kubectl describe resourcequota development-quota -n development
```

### Viewing Resource Usage

```bash
# Check resource usage against quotas
kubectl describe resourcequota -n development
kubectl describe resourcequota -n staging
kubectl describe resourcequota -n production

# Top command for resource usage (requires metrics-server)
kubectl top pods -n development
kubectl top nodes
```

## Limit Ranges

**Limit Ranges** enforce resource limits on individual objects within a namespace.

Create `limit-ranges.yaml`:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: development-limits
  namespace: development
spec:
  limits:
  - default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    max:
      cpu: "1"
      memory: "1Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
    type: Container

---
apiVersion: v1
kind: LimitRange
metadata:
  name: staging-limits
  namespace: staging
spec:
  limits:
  - default:
      cpu: "1"
      memory: "1Gi"
    defaultRequest:
      cpu: "250m"
      memory: "256Mi"
    max:
      cpu: "2"
      memory: "2Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
    type: Container

---
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limits
  namespace: production
spec:
  limits:
  - default:
      cpu: "2"
      memory: "2Gi"
    defaultRequest:
      cpu: "500m"
      memory: "512Mi"
    max:
      cpu: "4"
      memory: "4Gi"
    min:
      cpu: "250m"
      memory: "256Mi"
    type: Container
```

```bash
# Apply limit ranges
kubectl apply -f limit-ranges.yaml

# Check limit ranges
kubectl get limitrange -A
kubectl describe limitrange development-limits -n development
```

## Cross-Namespace Communication

### Service Discovery Across Namespaces

Services can be accessed from other namespaces using fully qualified domain names:

```bash
# Create a test pod in development namespace
kubectl run test-pod --image=busybox -n development -it --rm -- /bin/sh

# Inside the pod, test cross-namespace service access:
# nslookup webapp-service.staging.svc.cluster.local
# wget -qO- http://webapp-service.staging.svc.cluster.local
# exit
```

### ExternalName Services

Create services that point to services in other namespaces:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: shared-database
  namespace: development
spec:
  type: ExternalName
  externalName: mysql-service.production.svc.cluster.local
  ports:
  - port: 3306
```

## Network Policies (Namespace Isolation)

**Network Policies** can isolate traffic between namespaces.

Create `network-policies.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          environment: production

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-staging-to-production
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: webapp
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          environment: staging
    ports:
    - protocol: TCP
      port: 80
```

**Note**: Network policies require a network plugin that supports them (like Calico or Cilium). minikube's default network doesn't enforce network policies.

## RBAC with Namespaces

**Role-Based Access Control** can be scoped to namespaces.

### Creating Namespace-Specific Roles

Create `rbac.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: developer-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: development
subjects:
- kind: User
  name: developer
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: readonly-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: readonly-binding
  namespace: production
subjects:
- kind: User
  name: developer
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: readonly-role
  apiGroup: rbac.authorization.k8s.io
```

## Monitoring and Observability

### Namespace-Level Monitoring

```bash
# Resource usage by namespace
kubectl top pods --all-namespaces
kubectl top nodes

# Events by namespace
kubectl get events -n development
kubectl get events -n staging --sort-by=.metadata.creationTimestamp

# Resource quotas usage
kubectl describe resourcequota -A
```

### Labels for Organization

Use consistent labeling across namespaces:

```yaml
metadata:
  labels:
    environment: production
    team: backend
    app: webapp
    version: "1.2.3"
    cost-center: engineering
```

## Best Practices

### 1. Namespace Naming Conventions

```bash
# Good: Descriptive and consistent
webapp-development
webapp-staging
webapp-production
team-alpha-dev
team-alpha-prod

# Avoid: Generic or unclear names
test
temp
namespace1
```

### 2. Environment Separation

```yaml
# Separate environments
metadata:
  namespace: webapp-production
  labels:
    environment: production
    criticality: high
    backup-policy: daily
```

### 3. Resource Management

```yaml
# Always set resource quotas for shared clusters
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
```

### 4. Security Boundaries

```yaml
# Use network policies for isolation
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

## Troubleshooting Namespace Issues

### Common Problems

#### 1. Resource Not Found

```bash
# Check if you're in the right namespace
kubectl config current-context
kubectl config view --minify | grep namespace

# List resources in specific namespace
kubectl get all -n <namespace-name>
```

#### 2. Quota Exceeded

```bash
# Check quota usage
kubectl describe resourcequota -n <namespace-name>

# Check what's consuming resources
kubectl top pods -n <namespace-name>
```

#### 3. Cross-Namespace Access Issues

```bash
# Test DNS resolution
kubectl run test --image=busybox -n <namespace> -it --rm -- nslookup <service>.<target-namespace>.svc.cluster.local

# Check network policies
kubectl get networkpolicy -n <namespace>
```

## Practical Exercises

### Exercise 1: Multi-Environment Deployment

1. Create three namespaces: dev, staging, prod
2. Deploy the same application to each with different resource limits
3. Create environment-specific ConfigMaps
4. Test cross-namespace service discovery

### Exercise 2: Resource Management

1. Create resource quotas for each namespace
2. Try to exceed the quota and observe the behavior
3. Create limit ranges and deploy pods to see default limits applied

### Exercise 3: Namespace Isolation

1. Create network policies to isolate production namespace
2. Test that development pods cannot access production services
3. Allow specific communication patterns between namespaces

## Cleaning Up

```bash
# Delete applications from all namespaces
kubectl delete deployment webapp --all-namespaces
kubectl delete service webapp-service --all-namespaces
kubectl delete configmap webapp-config --all-namespaces

# Delete resource quotas and limit ranges
kubectl delete resourcequota --all --all-namespaces
kubectl delete limitrange --all --all-namespaces

# Delete network policies
kubectl delete networkpolicy --all --all-namespaces

# Delete custom namespaces (this deletes all resources in them)
kubectl delete namespace development staging production

# Reset default namespace context
kubectl config set-context --current --namespace=default
```

## Key Takeaways

1. **Namespaces provide logical isolation** - Separate resources without separate clusters
2. **Use namespaces for environments** - Development, staging, production separation
3. **Resource quotas prevent resource hogging** - Set limits per namespace
4. **Limit ranges provide defaults** - Automatic resource limits for containers
5. **Cross-namespace communication is possible** - Use FQDN for service discovery
6. **RBAC can be namespace-scoped** - Fine-grained access control
7. **Network policies enable isolation** - Control traffic between namespaces
8. **Consistent naming and labeling** - Essential for management and monitoring

## Commands Reference

| Command | Purpose |
|---------|---------|
| `kubectl get namespaces` | List namespaces |
| `kubectl create namespace <name>` | Create namespace |
| `kubectl delete namespace <name>` | Delete namespace |
| `kubectl get pods -n <namespace>` | List pods in namespace |
| `kubectl get pods -A` | List pods in all namespaces |
| `kubectl config set-context --current --namespace=<name>` | Set default namespace |
| `kubectl get resourcequota -A` | List resource quotas |
| `kubectl describe resourcequota <name> -n <namespace>` | Quota details |
| `kubectl get limitrange -A` | List limit ranges |
| `kubectl top pods -n <namespace>` | Resource usage by namespace |

---

**Next Chapter**: [Ingress and Load Balancing](../09-ingress/) - Learn advanced networking and traffic routing in Kubernetes.