# Exercise 4.1: Building and Applying Base Configuration

## Objective

In this exercise, you will create a complete base configuration for a web application, deploy it to minikube, and verify its functionality. This exercise reinforces the concepts from Chapter 4 and provides hands-on experience with real deployments.

## Prerequisites

- Completed Exercise 1.1 (Environment Setup)
- minikube running: `minikube status`
- Basic understanding of Kubernetes resources
- Chapter 4 content reviewed

## Overview

You'll create a blog application with the following components:
- **Frontend**: React-based web interface
- **Backend API**: Node.js REST API
- **Database**: PostgreSQL database
- **Cache**: Redis cache layer
- **Configuration**: Environment-specific settings

## Instructions

### Step 1: Create Project Structure

Create the directory structure for your blog application:

```bash
# Create the main project directory
mkdir blog-app && cd blog-app

# Create base and overlay directories
mkdir -p {base,overlays/development,overlays/staging}

# Create subdirectories for organization
mkdir -p base/{frontend,backend,database,cache,configs}
```

### Step 2: Create Frontend Resources

Create the frontend deployment and service:

**base/frontend/deployment.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: blog-app
    component: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: blog-app
      component: frontend
  template:
    metadata:
      labels:
        app: blog-app
        component: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:1.21-alpine
        ports:
        - containerPort: 80
          name: http
        env:
        - name: API_URL
          value: "http://backend:3000"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
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
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: frontend-config
```

**base/frontend/service.yaml**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  labels:
    app: blog-app
    component: frontend
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  selector:
    app: blog-app
    component: frontend
```

**base/frontend/configmap.yaml**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
  labels:
    app: blog-app
    component: frontend
data:
  default.conf: |
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
        }
        
        location /api/ {
            proxy_pass http://backend:3000/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
```

### Step 3: Create Backend Resources

**base/backend/deployment.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: blog-app
    component: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: blog-app
      component: backend
  template:
    metadata:
      labels:
        app: blog-app
        component: backend
    spec:
      containers:
      - name: backend
        image: node:16-alpine
        ports:
        - containerPort: 3000
          name: http
        command: ["node", "server.js"]
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "3000"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: url
        - name: REDIS_URL
          value: "redis://cache:6379"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
        volumeMounts:
        - name: app-code
          mountPath: /app
          readOnly: true
      volumes:
      - name: app-code
        configMap:
          name: backend-code
      workingDir: /app
```

**base/backend/service.yaml**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
  labels:
    app: blog-app
    component: backend
spec:
  type: ClusterIP
  ports:
  - port: 3000
    targetPort: 3000
    protocol: TCP
    name: http
  selector:
    app: blog-app
    component: backend
```

**base/backend/configmap.yaml**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-code
  labels:
    app: blog-app
    component: backend
data:
  server.js: |
    const express = require('express');
    const app = express();
    const port = process.env.PORT || 3000;
    
    app.use(express.json());
    
    // Health check endpoints
    app.get('/health', (req, res) => {
      res.status(200).send('OK');
    });
    
    app.get('/ready', (req, res) => {
      res.status(200).send('Ready');
    });
    
    // Blog API endpoints
    app.get('/posts', (req, res) => {
      res.json([
        { id: 1, title: 'First Post', content: 'Hello World!' },
        { id: 2, title: 'Second Post', content: 'Kustomize is awesome!' }
      ]);
    });
    
    app.get('/posts/:id', (req, res) => {
      const id = parseInt(req.params.id);
      const post = { id, title: `Post ${id}`, content: `Content for post ${id}` };
      res.json(post);
    });
    
    app.listen(port, () => {
      console.log(`Server running on port ${port}`);
    });
  
  package.json: |
    {
      "name": "blog-backend",
      "version": "1.0.0",
      "main": "server.js",
      "dependencies": {
        "express": "^4.18.0"
      }
    }
```

### Step 4: Create Database Resources

**base/database/deployment.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  labels:
    app: blog-app
    component: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: blog-app
      component: database
  template:
    metadata:
      labels:
        app: blog-app
        component: database
    spec:
      containers:
      - name: postgres
        image: postgres:13-alpine
        ports:
        - containerPort: 5432
          name: postgres
        env:
        - name: POSTGRES_DB
          value: "blogdb"
        - name: POSTGRES_USER
          value: "bloguser"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: password
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: init-scripts
          mountPath: /docker-entrypoint-initdb.d
          readOnly: true
      volumes:
      - name: postgres-data
        emptyDir: {}
      - name: init-scripts
        configMap:
          name: database-init
```

**base/database/service.yaml**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: database
  labels:
    app: blog-app
    component: database
spec:
  type: ClusterIP
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
    name: postgres
  selector:
    app: blog-app
    component: database
```

**base/database/configmap.yaml**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: database-init
  labels:
    app: blog-app
    component: database
data:
  01-init.sql: |
    -- Create posts table
    CREATE TABLE IF NOT EXISTS posts (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        content TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Insert sample data
    INSERT INTO posts (title, content) VALUES
    ('Welcome to our Blog', 'This is the first post on our new blog platform!'),
    ('Getting Started with Kubernetes', 'Learn how to deploy applications with Kubernetes and Kustomize.');
```

### Step 5: Create Cache Resources

**base/cache/deployment.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache
  labels:
    app: blog-app
    component: cache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: blog-app
      component: cache
  template:
    metadata:
      labels:
        app: blog-app
        component: cache
    spec:
      containers:
      - name: redis
        image: redis:6-alpine
        ports:
        - containerPort: 6379
          name: redis
        command: ["redis-server", "/etc/redis/redis.conf"]
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        volumeMounts:
        - name: redis-config
          mountPath: /etc/redis
          readOnly: true
        - name: redis-data
          mountPath: /data
      volumes:
      - name: redis-config
        configMap:
          name: redis-config
      - name: redis-data
        emptyDir: {}
```

**base/cache/service.yaml**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: cache
  labels:
    app: blog-app
    component: cache
spec:
  type: ClusterIP
  ports:
  - port: 6379
    targetPort: 6379
    protocol: TCP
    name: redis
  selector:
    app: blog-app
    component: cache
```

**base/cache/configmap.yaml**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  labels:
    app: blog-app
    component: cache
data:
  redis.conf: |
    # Redis configuration
    maxmemory 100mb
    maxmemory-policy allkeys-lru
    save 900 1
    save 300 10
    save 60 10000
    appendonly yes
    appendfsync everysec
```

### Step 6: Create Secrets

**base/secrets.yaml**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-secret
  labels:
    app: blog-app
    component: database
type: Opaque
data:
  password: YmxvZ3Bhc3N3b3Jk  # "blogpassword" in base64
  url: cG9zdGdyZXNxbDovL2Jsb2d1c2VyOmJsb2dwYXNzd29yZEBkYXRhYmFzZTo1NDMyL2Jsb2dkYg==  # connection URL in base64
```

### Step 7: Create Base Kustomization

**base/kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: blog-app-base

# Include all component resources
resources:
  - frontend/deployment.yaml
  - frontend/service.yaml
  - frontend/configmap.yaml
  - backend/deployment.yaml
  - backend/service.yaml
  - backend/configmap.yaml
  - database/deployment.yaml
  - database/service.yaml
  - database/configmap.yaml
  - cache/deployment.yaml
  - cache/service.yaml
  - cache/configmap.yaml
  - secrets.yaml

# Common labels for all resources
commonLabels:
  app: blog-app
  managed-by: kustomize
  version: v1.0.0

# Common annotations
commonAnnotations:
  description: "Multi-tier blog application"
  documentation: "https://github.com/example/blog-app"

# Default namespace
namespace: blog-app
```

### Step 8: Build and Validate Base Configuration

```bash
# Build the base configuration
kustomize build base/

# Validate the output
kustomize build base/ | kubectl apply --dry-run=client -f -

# Check the structure
echo "Resources in base configuration:"
kustomize build base/ | grep -E "^(kind|metadata):" -A 1 | grep -E "(kind|name):"
```

### Step 9: Deploy to minikube

```bash
# Create namespace
kubectl create namespace blog-app

# Deploy the application
kubectl apply -k base/

# Verify deployment
kubectl get all -n blog-app

# Check pod status
kubectl get pods -n blog-app -w
```

### Step 10: Create Development Overlay

**overlays/development/patches.yaml**:
```yaml
# Reduce resources for development
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: frontend
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: backend
        env:
        - name: NODE_ENV
          value: "development"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"

---
# Expose frontend via NodePort for easy access
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
    protocol: TCP
    name: http
```

**overlays/development/kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: blog-app-development

# Reference base configuration
resources:
  - ../../base

# Development-specific settings
namePrefix: dev-
namespace: blog-app-dev

# Additional labels
commonLabels:
  environment: development

# Apply development patches
patches:
  - path: patches.yaml

# Development-specific ConfigMap
configMapGenerator:
  - name: dev-config
    literals:
      - DEBUG_MODE=true
      - LOG_LEVEL=debug
      - ENVIRONMENT=development
```

### Step 11: Deploy Development Environment

```bash
# Create development namespace
kubectl create namespace blog-app-dev

# Deploy development version
kubectl apply -k overlays/development/

# Verify development deployment
kubectl get all -n blog-app-dev

# Access the application
minikube service dev-frontend -n blog-app-dev --url
```

## Expected Results

After completing all steps, you should have:

1. **Base Configuration**: A complete multi-tier application with frontend, backend, database, and cache
2. **Working Deployment**: All pods running and healthy in the `blog-app` namespace
3. **Development Overlay**: A customized development environment with reduced resources
4. **Accessible Application**: Frontend accessible via NodePort in development environment

## Verification

### 1. Check All Pods Are Running

```bash
# Base environment
kubectl get pods -n blog-app
# All pods should show "Running" status

# Development environment  
kubectl get pods -n blog-app-dev
# All pods should show "Running" status with "dev-" prefix
```

### 2. Test Application Connectivity

```bash
# Test frontend in development
curl $(minikube service dev-frontend -n blog-app-dev --url)

# Test backend API
kubectl port-forward -n blog-app-dev service/dev-backend 3000:3000 &
curl http://localhost:3000/posts
curl http://localhost:3000/health
```

### 3. Verify Database Connection

```bash
# Connect to database and verify tables
kubectl exec -it -n blog-app-dev deployment/dev-database -- psql -U bloguser -d blogdb -c "\\dt"
kubectl exec -it -n blog-app-dev deployment/dev-database -- psql -U bloguser -d blogdb -c "SELECT * FROM posts;"
```

### 4. Test Cache Functionality

```bash
# Connect to Redis and test
kubectl exec -it -n blog-app-dev deployment/dev-cache -- redis-cli ping
kubectl exec -it -n blog-app-dev deployment/dev-cache -- redis-cli info memory
```

### 5. Compare Base vs Development

```bash
# Compare resource differences
echo "=== BASE RESOURCES ==="
kustomize build base/ | grep "cpu:" -A 1 -B 1

echo "=== DEVELOPMENT RESOURCES ==="
kustomize build overlays/development/ | grep "cpu:" -A 1 -B 1
```

## Extension Challenges

### Challenge 1: Add Monitoring

Add a monitoring component with Prometheus metrics:

1. Create `base/monitoring/` directory
2. Add Prometheus deployment and service
3. Configure service discovery for application metrics
4. Update base kustomization to include monitoring

### Challenge 2: Implement Health Checks

Enhance the health check system:

1. Add comprehensive liveness and readiness probes
2. Implement startup probes for slow-starting containers
3. Create a health check dashboard ConfigMap
4. Test failover scenarios

### Challenge 3: Create Staging Overlay

Build a staging environment overlay:

1. Create `overlays/staging/` directory
2. Scale up replicas for load testing
3. Add resource limits appropriate for staging
4. Include additional monitoring and logging

### Challenge 4: Add Ingress

Expose the application via Ingress:

1. Enable ingress addon in minikube
2. Create Ingress resource for frontend
3. Configure SSL/TLS certificates
4. Test external access

### Challenge 5: Implement Persistent Storage

Add persistent storage for database:

1. Create PersistentVolumeClaim for PostgreSQL
2. Update database deployment to use PVC
3. Test data persistence across pod restarts
4. Implement backup strategy

## Solutions

Reference solutions are available in the `/solutions/exercise-4.1/` directory. Compare your implementation with the provided solutions to identify areas for improvement.

## Common Issues

### Pod Stuck in Pending State
- **Check**: Resource quotas and node capacity
- **Solution**: Reduce resource requests or scale cluster

### ImagePullBackOff Errors  
- **Check**: Image names and tags
- **Solution**: Verify images exist or use alternative images

### Service Connection Errors
- **Check**: Service selectors and port configurations
- **Solution**: Ensure labels and ports match between services and deployments

### ConfigMap/Secret Not Found
- **Check**: Resource creation order and names
- **Solution**: Verify all resources are included in kustomization.yaml

## Troubleshooting

For detailed troubleshooting guidance, refer to:
- [Appendix B: Troubleshooting Guide](../../appendices/b-troubleshooting.md)
- [Chapter 4: Your First Kustomization](../../chapters/04-first-kustomization.md)
- Exercise-specific logs: `kubectl logs -f deployment/<deployment-name> -n <namespace>`

## Next Steps

After completing this exercise:
1. Move on to [Exercise 5.1: Creating Environment Overlays](../exercise-5.1/)
2. Experiment with different patch strategies
3. Explore additional Kubernetes resources
4. Practice debugging and troubleshooting techniques

Congratulations on completing your first comprehensive Kustomize deployment!