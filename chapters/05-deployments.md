# Chapter 5: Deployments and ReplicaSets

## Learning Objectives

By the end of this chapter, you will understand:
- What Deployments and ReplicaSets are and how they work together
- How to manage application lifecycle with Deployments
- Scaling applications up and down
- Rolling updates and rollbacks
- Deployment strategies and best practices

## The Problem: Managing Pod Lifecycle

So far, we've created individual Pods and Services. However, in production, we need:

1. **High Availability**: Multiple instances of our application
2. **Self-Healing**: Automatic restart of failed Pods
3. **Scaling**: Easy scaling up/down based on demand
4. **Updates**: Safe deployment of new application versions
5. **Rollbacks**: Quick recovery from problematic deployments

## What is a ReplicaSet?

A **ReplicaSet** ensures that a specified number of Pod replicas are running at any given time. If a Pod fails, the ReplicaSet creates a new one.

### ReplicaSet Characteristics

1. **Desired State**: Maintains specified number of replicas
2. **Self-Healing**: Replaces failed Pods automatically
3. **Label Selector**: Uses labels to identify which Pods to manage
4. **Pod Template**: Defines what new Pods should look like

### ReplicaSet Example

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-replicaset
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
```

## What is a Deployment?

A **Deployment** is a higher-level object that manages ReplicaSets and provides declarative updates to Pods. It's the recommended way to manage stateless applications.

### Deployment vs ReplicaSet

- **ReplicaSet**: Manages Pod replicas at a point in time
- **Deployment**: Manages ReplicaSets over time, handling updates and rollbacks

### Deployment Benefits

1. **Rolling Updates**: Deploy new versions without downtime
2. **Rollback Capability**: Easy reversion to previous versions
3. **Update History**: Track deployment changes
4. **Declarative Management**: Define desired state, Kubernetes handles the transition

## Your First Deployment

Let's create a simple nginx Deployment and explore its features.

### Creating a Basic Deployment

Create `nginx-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
```

```bash
# Create the deployment
kubectl apply -f nginx-deployment.yaml

# Check the deployment
kubectl get deployments
kubectl get replicasets
kubectl get pods

# Get detailed information
kubectl describe deployment nginx-deployment
```

### Understanding Deployment YAML Structure

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment     # Deployment name
  labels:
    app: nginx              # Labels for the Deployment itself
spec:
  replicas: 3               # Desired number of Pod replicas
  selector:                 # How to find Pods to manage
    matchLabels:
      app: nginx            # Must match template labels
  template:                 # Pod template (same as Pod spec)
    metadata:
      labels:
        app: nginx          # Labels for created Pods
    spec:
      containers:           # Container specification
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
```

## Scaling Applications

One of the key benefits of Deployments is easy scaling.

### Manual Scaling

```bash
# Scale up to 5 replicas
kubectl scale deployment nginx-deployment --replicas=5

# Verify scaling
kubectl get pods
kubectl get deployment nginx-deployment

# Scale down to 2 replicas
kubectl scale deployment nginx-deployment --replicas=2

# Watch the scaling process
kubectl get pods -w
```

### Declarative Scaling

Edit your `nginx-deployment.yaml` file:

```yaml
spec:
  replicas: 4  # Change from 3 to 4
```

```bash
# Apply the change
kubectl apply -f nginx-deployment.yaml

# Verify the change
kubectl get deployment nginx-deployment
```

### Auto-scaling (Preview)

While detailed auto-scaling is covered later, here's a preview:

```bash
# Create horizontal pod autoscaler (requires metrics-server)
kubectl autoscale deployment nginx-deployment --cpu-percent=50 --min=3 --max=10

# View autoscaler
kubectl get hpa
```

## Rolling Updates

Deployments excel at rolling updates - updating applications without downtime.

### Performing a Rolling Update

```bash
# Update the nginx image
kubectl set image deployment/nginx-deployment nginx=nginx:1.22

# Watch the rollout
kubectl rollout status deployment/nginx-deployment

# Check rollout history
kubectl rollout history deployment/nginx-deployment
```

### Understanding Rolling Update Process

1. **New ReplicaSet Created**: For the new version
2. **Gradual Scale Up/Down**: New Pods created, old Pods terminated
3. **Health Checks**: Ensures new Pods are ready before continuing
4. **Complete Transition**: All Pods eventually use new version

### Rolling Update with YAML

Update your `nginx-deployment.yaml`:

```yaml
spec:
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:1.22  # Updated version
        ports:
        - containerPort: 80
```

```bash
# Apply the update
kubectl apply -f nginx-deployment.yaml

# Monitor the update
kubectl get pods -w
kubectl rollout status deployment/nginx-deployment
```

## Deployment History and Rollbacks

Deployments maintain a history of changes, enabling easy rollbacks.

### Viewing Deployment History

```bash
# See rollout history
kubectl rollout history deployment/nginx-deployment

# Get details of specific revision
kubectl rollout history deployment/nginx-deployment --revision=2

# Check current deployment details
kubectl describe deployment nginx-deployment
```

### Rolling Back Deployments

```bash
# Rollback to previous version
kubectl rollout undo deployment/nginx-deployment

# Rollback to specific revision
kubectl rollout undo deployment/nginx-deployment --to-revision=1

# Verify rollback
kubectl rollout status deployment/nginx-deployment
kubectl get pods
```

### Setting Revision History Limit

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  revisionHistoryLimit: 5  # Keep only 5 previous ReplicaSets
  replicas: 3
  # ... rest of spec
```

## Deployment Strategies

### 1. Rolling Update (Default)

Gradually replace old Pods with new ones:

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1      # Max Pods that can be unavailable
      maxSurge: 1           # Max Pods above desired replica count
```

### 2. Recreate Strategy

Terminate all old Pods before creating new ones:

```yaml
spec:
  strategy:
    type: Recreate
```

**Note**: This causes downtime but ensures no mixed versions.

## Advanced Deployment Features

### 1. Pod Template with Resource Limits

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-with-resources
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
```

### 2. Health Checks in Deployments

```yaml
spec:
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
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
```

### 3. Environment Variables and Configuration

```yaml
spec:
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        env:
        - name: ENVIRONMENT
          value: "production"
        - name: LOG_LEVEL
          value: "info"
        ports:
        - containerPort: 80
```

## Hands-On Exercises

### Exercise 1: Create and Scale a Deployment

```bash
# Create a simple deployment
kubectl create deployment web-app --image=nginx:1.21

# Scale it to 4 replicas
kubectl scale deployment web-app --replicas=4

# Verify scaling
kubectl get deployment web-app
kubectl get pods -l app=web-app
```

### Exercise 2: Perform Rolling Update

```bash
# Update the image
kubectl set image deployment/web-app nginx=nginx:1.22

# Watch the update process
kubectl rollout status deployment/web-app

# Check the pods to see new image
kubectl describe pods -l app=web-app | grep Image
```

### Exercise 3: Rollback Deployment

```bash
# View rollout history
kubectl rollout history deployment/web-app

# Rollback to previous version
kubectl rollout undo deployment/web-app

# Verify rollback
kubectl rollout status deployment/web-app
```

## Practical Example: Web Application with Database

Let's create a more realistic example with a web application and database:

```yaml
# Database Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "password123"
        - name: MYSQL_DATABASE
          value: "webapp"
        ports:
        - containerPort: 3306

---
# Database Service
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
spec:
  selector:
    app: mysql
  ports:
  - port: 3306
    targetPort: 3306

---
# Web Application Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-deployment
spec:
  replicas: 3
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
        env:
        - name: DATABASE_HOST
          value: "mysql-service"
        - name: DATABASE_PORT
          value: "3306"
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"

---
# Web Application Service
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  type: NodePort
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```

```bash
# Deploy the complete application
kubectl apply -f complete-app.yaml

# Verify all components
kubectl get deployments
kubectl get services
kubectl get pods

# Access the application
minikube service webapp-service
```

## Troubleshooting Deployments

### Common Issues and Solutions

#### 1. Deployment Stuck in Progress

```bash
# Check deployment status
kubectl describe deployment <deployment-name>

# Check pod status
kubectl get pods -l app=<app-label>

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp
```

**Common causes**:
- Image pull errors
- Resource constraints
- Failed health checks
- Configuration errors

#### 2. Rollout Failed

```bash
# Check rollout status
kubectl rollout status deployment/<deployment-name>

# View deployment conditions
kubectl describe deployment <deployment-name>

# Rollback if needed
kubectl rollout undo deployment/<deployment-name>
```

#### 3. Pods Not Ready

```bash
# Check pod details
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Check resource usage
kubectl top pods
```

## Best Practices

### 1. Resource Management
- Always set resource requests and limits
- Use appropriate CPU and memory values
- Monitor resource usage

### 2. Health Checks
- Implement readiness probes for zero-downtime deployments
- Use liveness probes for self-healing
- Set appropriate timeout values

### 3. Update Strategy
- Use rolling updates for zero-downtime deployments
- Set appropriate `maxUnavailable` and `maxSurge` values
- Test updates in non-production environments first

### 4. Labeling
- Use consistent labeling strategy
- Include version, environment, and component labels
- Use labels for monitoring and debugging

### 5. Configuration Management
- Externalize configuration using ConfigMaps/Secrets
- Use environment-specific values
- Keep sensitive data in Secrets

## Cleaning Up

```bash
# Delete specific deployment
kubectl delete deployment nginx-deployment

# Delete all resources with specific label
kubectl delete all -l app=nginx

# Delete multiple deployments
kubectl delete deployment web-app webapp-deployment mysql-deployment
```

## Key Takeaways

1. **Deployments manage ReplicaSets** - Higher-level abstraction for application lifecycle
2. **Scaling is simple** - Declarative or imperative scaling options
3. **Rolling updates enable zero-downtime deployments** - Gradual replacement of Pods
4. **Rollbacks provide safety net** - Easy reversion to previous versions
5. **Health checks ensure reliability** - Readiness and liveness probes prevent issues
6. **Resource management is crucial** - Set appropriate limits and requests

## Commands Reference

| Command | Purpose |
|---------|---------|
| `kubectl create deployment <name> --image=<image>` | Create deployment |
| `kubectl get deployments` | List deployments |
| `kubectl describe deployment <name>` | Deployment details |
| `kubectl scale deployment <name> --replicas=<number>` | Scale deployment |
| `kubectl set image deployment/<name> <container>=<image>` | Update image |
| `kubectl rollout status deployment/<name>` | Check rollout status |
| `kubectl rollout history deployment/<name>` | View rollout history |
| `kubectl rollout undo deployment/<name>` | Rollback deployment |
| `kubectl delete deployment <name>` | Delete deployment |

---

**Next Chapter**: [ConfigMaps and Secrets](../06-config-secrets/) - Learn how to manage configuration data and sensitive information in Kubernetes.