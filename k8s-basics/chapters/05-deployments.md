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

Kubernetes offers different deployment strategies to handle application updates. Understanding these strategies is crucial for maintaining application availability and controlling the update process.

### 1. Rolling Update (Default)

The rolling update strategy gradually replaces old Pods with new ones, ensuring continuous availability.

#### Basic Rolling Update Configuration

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolling-update-demo
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1      # Max Pods that can be unavailable
      maxSurge: 1           # Max Pods above desired replica count
  selector:
    matchLabels:
      app: rolling-demo
  template:
    metadata:
      labels:
        app: rolling-demo
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
```

#### Advanced Rolling Update Configurations

**Zero-downtime deployment for single replica:**
```yaml
spec:
  replicas: 1
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0      # Never take down the only Pod
      maxSurge: 1           # Allow one extra Pod during update
```

**Conservative update (slow and steady):**
```yaml
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1      # Only 1 Pod down at a time
      maxSurge: 1           # Only 1 extra Pod at a time
```

**Aggressive update (faster deployment):**
```yaml
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%    # Up to 25% of Pods can be down
      maxSurge: 25%         # Up to 25% extra Pods allowed
```

#### Rolling Update Process Visualization

```
Initial State:  [V1] [V1] [V1] [V1] [V1]    (5 replicas)

Step 1:         [V1] [V1] [V1] [V1] [V1] [V2]  (maxSurge: +1)
Step 2:         [V1] [V1] [V1] [V1] [V2]       (terminate 1 old)
Step 3:         [V1] [V1] [V1] [V1] [V2] [V2]  (add 1 new)
Step 4:         [V1] [V1] [V1] [V2] [V2]       (terminate 1 old)
...
Final State:    [V2] [V2] [V2] [V2] [V2]       (all updated)
```

### 2. Recreate Strategy

Terminates all existing Pods before creating new ones. This causes downtime but ensures no version mixing.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recreate-demo
spec:
  replicas: 3
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: recreate-demo
  template:
    metadata:
      labels:
        app: recreate-demo
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
```

#### When to Use Recreate Strategy

- **Database migrations**: When you need to ensure no old version remains
- **Shared resources**: Applications that can't run multiple versions simultaneously
- **Development/testing**: When downtime is acceptable
- **Resource constraints**: When you can't afford extra Pods during updates

#### Recreate Process Visualization

```
Initial State:  [V1] [V1] [V1]
Terminating:    [ ]  [ ]  [ ]    (all Pods terminated)
Creating:       [V2] [V2] [V2]   (new Pods created)
```

### 3. Blue-Green Deployment Strategy

While not directly supported by Kubernetes Deployments, you can implement blue-green deployments using multiple Deployments and Services.

#### Blue-Green Setup

```yaml
# Blue Deployment (current version)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
  labels:
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80

---
# Green Deployment (new version)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
  labels:
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: app
        image: nginx:1.22
        ports:
        - containerPort: 80

---
# Service (switch between blue and green)
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: myapp
    version: blue  # Switch to 'green' for deployment
  ports:
  - port: 80
    targetPort: 80
```

#### Blue-Green Deployment Commands

```bash
# Deploy green version
kubectl apply -f app-green-deployment.yaml

# Verify green deployment is ready
kubectl get pods -l version=green

# Switch traffic to green
kubectl patch service app-service -p '{"spec":{"selector":{"version":"green"}}}'

# Verify the switch
kubectl get service app-service -o yaml

# Clean up blue deployment (after verification)
kubectl delete deployment app-blue
```

### 4. Canary Deployment Strategy

Gradually shift traffic from old to new version by controlling the number of replicas.

#### Canary Deployment Example

```yaml
# Main deployment (90% of traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-main
spec:
  replicas: 9
  selector:
    matchLabels:
      app: myapp
      track: stable
  template:
    metadata:
      labels:
        app: myapp
        track: stable
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80

---
# Canary deployment (10% of traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
      track: canary
  template:
    metadata:
      labels:
        app: myapp
        track: canary
    spec:
      containers:
      - name: app
        image: nginx:1.22  # New version
        ports:
        - containerPort: 80

---
# Service routes to both deployments
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: myapp  # Matches both stable and canary
  ports:
  - port: 80
    targetPort: 80
```

#### Canary Deployment Progression

```bash
# Start with canary (10% traffic)
kubectl apply -f canary-deployment.yaml

# Monitor canary performance
kubectl get pods -l track=canary
kubectl logs -l track=canary

# Increase canary traffic (20%)
kubectl scale deployment app-canary --replicas=2
kubectl scale deployment app-main --replicas=8

# Further increase (50%)
kubectl scale deployment app-canary --replicas=5
kubectl scale deployment app-main --replicas=5

# Complete rollout (100% canary)
kubectl scale deployment app-canary --replicas=10
kubectl scale deployment app-main --replicas=0

# Clean up old deployment
kubectl delete deployment app-main
```

### 5. Advanced Rollout Control

Kubernetes provides advanced options to control the rollout process.

#### Rollout Configuration with Timing

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: controlled-rollout
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 2
      maxSurge: 2
  minReadySeconds: 30        # Wait 30s before considering Pod ready
  progressDeadlineSeconds: 300  # Rollout timeout (5 minutes)
  selector:
    matchLabels:
      app: controlled-app
  template:
    metadata:
      labels:
        app: controlled-app
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
          successThreshold: 2    # Must succeed twice
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
```

#### Manual Rollout Control

```bash
# Pause a rollout
kubectl rollout pause deployment/myapp

# Check rollout status
kubectl rollout status deployment/myapp

# Resume rollout
kubectl rollout resume deployment/myapp

# Restart rollout (force update without changing image)
kubectl rollout restart deployment/myapp
```

### 6. Rollout Annotations and Change Cause

Track deployment changes with annotations:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: annotated-deployment
  annotations:
    deployment.kubernetes.io/revision: "3"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
      annotations:
        # This annotation is recorded in rollout history
        kubernetes.io/change-cause: "Update to nginx 1.22 for security patch"
    spec:
      containers:
      - name: nginx
        image: nginx:1.22
        ports:
        - containerPort: 80
```

```bash
# Set change cause when updating
kubectl set image deployment/myapp nginx=nginx:1.22 \
  --record=true \
  --annotations="kubernetes.io/change-cause=Security update to nginx 1.22"

# View detailed history with change causes
kubectl rollout history deployment/myapp
kubectl rollout history deployment/myapp --revision=3
```

### 7. Strategy Selection Guide

| Strategy | Downtime | Resource Usage | Complexity | Use Case |
|----------|----------|----------------|------------|----------|
| **Rolling Update** | None | Low | Low | Most applications, default choice |
| **Recreate** | Yes | Lowest | Lowest | Stateful apps, databases |
| **Blue-Green** | None | Highest | Medium | Critical apps, instant rollback needed |
| **Canary** | None | Medium | High | Risk-averse updates, A/B testing |

### 8. Testing Deployment Strategies

#### Create Test Deployment

```yaml
# test-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: strategy-test
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: strategy-test
  template:
    metadata:
      labels:
        app: strategy-test
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 2
```

#### Test Commands

```bash
# Deploy initial version
kubectl apply -f test-deployment.yaml

# Watch pods in real-time
kubectl get pods -l app=strategy-test -w

# In another terminal, trigger update
kubectl set image deployment/strategy-test nginx=nginx:1.22

# Monitor the rollout
kubectl rollout status deployment/strategy-test

# Check replica sets
kubectl get replicasets -l app=strategy-test

# Test rollback
kubectl rollout undo deployment/strategy-test
```

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