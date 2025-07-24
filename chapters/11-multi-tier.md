# Chapter 11: Multi-Tier Application Deployment

## Learning Objectives

By the end of this chapter, you will understand:
- How to design and deploy multi-tier applications
- Frontend, backend, and database integration patterns
- Service discovery and communication between tiers
- Configuration management across application layers
- Deployment strategies for complex applications
- Real-world application architecture in Kubernetes

## Multi-Tier Application Architecture

A typical web application consists of multiple tiers:

### 1. Presentation Tier (Frontend)
- **Purpose**: User interface and user experience
- **Technologies**: React, Vue.js, Angular, static HTML/CSS/JS
- **Kubernetes**: Deployed as static content server (nginx) or Node.js app

### 2. Application Tier (Backend/API)
- **Purpose**: Business logic, API endpoints, data processing
- **Technologies**: Node.js, Python Flask/Django, Java Spring, Go
- **Kubernetes**: Deployed as microservices or monolithic API

### 3. Data Tier (Database)
- **Purpose**: Data storage, persistence, and retrieval
- **Technologies**: MySQL, PostgreSQL, MongoDB, Redis
- **Kubernetes**: Deployed with persistent storage

### 4. Supporting Services
- **Cache Layer**: Redis, Memcached
- **Message Queue**: RabbitMQ, Apache Kafka
- **External Services**: Third-party APIs, cloud services

## Complete Todo Application Example

Let's build a complete todo application with:
- **Frontend**: React application served by nginx
- **Backend**: Node.js API server
- **Database**: MySQL for persistent storage
- **Cache**: Redis for session storage

### Application Architecture

```
Internet → Ingress → Frontend (nginx) → Backend API (Node.js) → Database (MySQL)
                                     ↓
                                Cache (Redis)
```

## Step 1: Database Layer

### MySQL Deployment with Persistent Storage

Create `mysql-deployment.yaml`:

```yaml
# MySQL ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
data:
  mysql.cnf: |
    [mysqld]
    default-authentication-plugin=mysql_native_password
    character-set-server=utf8mb4
    collation-server=utf8mb4_unicode_ci
    max_connections=200
    innodb_buffer_pool_size=128M

---
# MySQL Secret
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
type: Opaque
stringData:
  root-password: "rootpassword123"
  database: "todoapp"
  username: "todouser"
  password: "todopassword123"

---
# MySQL Persistent Volume
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /tmp/mysql-data

---
# MySQL Persistent Volume Claim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi

---
# MySQL Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  labels:
    app: mysql
    tier: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
        tier: database
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: root-password
        - name: MYSQL_DATABASE
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: database
        - name: MYSQL_USER
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: username
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
        - name: mysql-config
          mountPath: /etc/mysql/conf.d
        livenessProbe:
          exec:
            command:
            - mysqladmin
            - ping
            - -h
            - localhost
            - -u
            - root
            - -p$(MYSQL_ROOT_PASSWORD)
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - mysql
            - -h
            - localhost
            - -u
            - root
            - -p$(MYSQL_ROOT_PASSWORD)
            - -e
            - "SELECT 1"
          initialDelaySeconds: 10
          periodSeconds: 5
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc
      - name: mysql-config
        configMap:
          name: mysql-config

---
# MySQL Service
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
  labels:
    app: mysql
spec:
  selector:
    app: mysql
  ports:
  - port: 3306
    targetPort: 3306
    name: mysql
  type: ClusterIP
```

## Step 2: Cache Layer

### Redis Deployment

Create `redis-deployment.yaml`:

```yaml
# Redis ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
data:
  redis.conf: |
    maxmemory 256mb
    maxmemory-policy allkeys-lru
    save 900 1
    save 300 10
    save 60 10000
    appendonly yes

---
# Redis Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  labels:
    app: redis
    tier: cache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        tier: cache
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        command:
        - redis-server
        - /etc/redis/redis.conf
        ports:
        - containerPort: 6379
          name: redis
        volumeMounts:
        - name: redis-config
          mountPath: /etc/redis
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 15
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: redis-config
        configMap:
          name: redis-config

---
# Redis Service
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  labels:
    app: redis
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
    name: redis
  type: ClusterIP
```

## Step 3: Backend API Layer

### Node.js API Server

Create `backend-deployment.yaml`:

```yaml
# Backend ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
data:
  NODE_ENV: "production"
  PORT: "3000"
  DB_HOST: "mysql-service"
  DB_PORT: "3306"
  DB_NAME: "todoapp"
  REDIS_HOST: "redis-service"
  REDIS_PORT: "6379"
  API_VERSION: "v1"
  CORS_ORIGIN: "*"

---
# Backend Secret
apiVersion: v1
kind: Secret
metadata:
  name: backend-secret
type: Opaque
stringData:
  DB_USERNAME: "todouser"
  DB_PASSWORD: "todopassword123"
  JWT_SECRET: "supersecretjwtkey123"
  API_KEY: "backend-api-key-xyz789"

---
# Backend Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
    tier: api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        tier: api
    spec:
      containers:
      - name: backend
        image: node:18-alpine
        command:
        - /bin/sh
        - -c
        - |
          # Create a simple Node.js API server
          cat > /app/package.json << 'EOF'
          {
            "name": "todo-api",
            "version": "1.0.0",
            "main": "server.js",
            "dependencies": {
              "express": "4.18.2",
              "mysql2": "3.6.0",
              "redis": "4.6.7",
              "cors": "2.8.5",
              "body-parser": "1.20.2"
            }
          }
          EOF

          cat > /app/server.js << 'EOF'
          const express = require('express');
          const mysql = require('mysql2/promise');
          const redis = require('redis');
          const cors = require('cors');
          const bodyParser = require('body-parser');

          const app = express();
          const port = process.env.PORT || 3000;

          app.use(cors());
          app.use(bodyParser.json());

          // Database connection
          const dbConfig = {
            host: process.env.DB_HOST,
            port: process.env.DB_PORT,
            user: process.env.DB_USERNAME,
            password: process.env.DB_PASSWORD,
            database: process.env.DB_NAME
          };

          // Redis connection
          const redisClient = redis.createClient({
            host: process.env.REDIS_HOST,
            port: process.env.REDIS_PORT
          });

          // Health check endpoint
          app.get('/health', (req, res) => {
            res.json({ status: 'healthy', timestamp: new Date().toISOString() });
          });

          // API routes
          app.get('/api/todos', async (req, res) => {
            try {
              const connection = await mysql.createConnection(dbConfig);
              const [rows] = await connection.execute('SELECT * FROM todos ORDER BY created_at DESC');
              await connection.end();
              res.json(rows);
            } catch (error) {
              res.status(500).json({ error: error.message });
            }
          });

          app.post('/api/todos', async (req, res) => {
            try {
              const { title, description } = req.body;
              const connection = await mysql.createConnection(dbConfig);
              const [result] = await connection.execute(
                'INSERT INTO todos (title, description, completed, created_at) VALUES (?, ?, false, NOW())',
                [title, description]
              );
              await connection.end();
              res.json({ id: result.insertId, title, description, completed: false });
            } catch (error) {
              res.status(500).json({ error: error.message });
            }
          });

          app.listen(port, () => {
            console.log(`Server running on port ${port}`);
          });
          EOF

          cd /app
          npm install
          node server.js
        ports:
        - containerPort: 3000
          name: http
        env:
        # Environment variables from ConfigMap
        - name: NODE_ENV
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: NODE_ENV
        - name: PORT
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: PORT
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: DB_HOST
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: DB_PORT
        - name: DB_NAME
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: DB_NAME
        - name: REDIS_HOST
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: REDIS_HOST
        - name: REDIS_PORT
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: REDIS_PORT
        # Environment variables from Secret
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: backend-secret
              key: DB_USERNAME
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: backend-secret
              key: DB_PASSWORD
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: backend-secret
              key: JWT_SECRET
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
# Backend Service
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  labels:
    app: backend
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 3000
    name: http
  type: ClusterIP
```

## Step 4: Frontend Layer

### React Frontend with Nginx

Create `frontend-deployment.yaml`:

```yaml
# Frontend ConfigMap with nginx configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
data:
  nginx.conf: |
    events {
        worker_connections 1024;
    }
    http {
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        
        upstream backend {
            server backend-service:80;
        }
        
        server {
            listen 80;
            server_name localhost;
            root /usr/share/nginx/html;
            index index.html;
            
            # Serve static files
            location / {
                try_files $uri $uri/ /index.html;
            }
            
            # Proxy API requests to backend
            location /api/ {
                proxy_pass http://backend;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
            }
            
            # Health check endpoint
            location /health {
                access_log off;
                return 200 "healthy\n";
                add_header Content-Type text/plain;
            }
        }
    }
  index.html: |
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Todo App</title>
        <style>
            body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
            .todo-item { border: 1px solid #ddd; margin: 10px 0; padding: 15px; border-radius: 5px; }
            .completed { background-color: #f0f8f0; }
            input, textarea, button { margin: 5px; padding: 10px; }
            button { background: #007bff; color: white; border: none; border-radius: 3px; cursor: pointer; }
            button:hover { background: #0056b3; }
        </style>
    </head>
    <body>
        <h1>Todo Application</h1>
        <div id="add-todo">
            <h3>Add New Todo</h3>
            <input type="text" id="title" placeholder="Todo title" />
            <textarea id="description" placeholder="Description"></textarea>
            <button onclick="addTodo()">Add Todo</button>
        </div>
        <div id="todos"></div>

        <script>
            const API_BASE = '/api';
            
            async function loadTodos() {
                try {
                    const response = await fetch(`${API_BASE}/todos`);
                    const todos = await response.json();
                    renderTodos(todos);
                } catch (error) {
                    console.error('Error loading todos:', error);
                    document.getElementById('todos').innerHTML = '<p>Error loading todos</p>';
                }
            }
            
            function renderTodos(todos) {
                const container = document.getElementById('todos');
                container.innerHTML = '<h3>Todo List</h3>';
                
                if (todos.length === 0) {
                    container.innerHTML += '<p>No todos found</p>';
                    return;
                }
                
                todos.forEach(todo => {
                    const todoElement = document.createElement('div');
                    todoElement.className = `todo-item ${todo.completed ? 'completed' : ''}`;
                    todoElement.innerHTML = `
                        <h4>${todo.title}</h4>
                        <p>${todo.description || 'No description'}</p>
                        <small>Created: ${new Date(todo.created_at).toLocaleString()}</small>
                    `;
                    container.appendChild(todoElement);
                });
            }
            
            async function addTodo() {
                const title = document.getElementById('title').value;
                const description = document.getElementById('description').value;
                
                if (!title.trim()) {
                    alert('Please enter a title');
                    return;
                }
                
                try {
                    const response = await fetch(`${API_BASE}/todos`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({ title, description }),
                    });
                    
                    if (response.ok) {
                        document.getElementById('title').value = '';
                        document.getElementById('description').value = '';
                        loadTodos();
                    } else {
                        alert('Error adding todo');
                    }
                } catch (error) {
                    console.error('Error adding todo:', error);
                    alert('Error adding todo');
                }
            }
            
            // Load todos on page load
            loadTodos();
        </script>
    </body>
    </html>

---
# Frontend Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
    tier: presentation
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: presentation
    spec:
      containers:
      - name: frontend
        image: nginx:1.21-alpine
        ports:
        - containerPort: 80
          name: http
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        - name: frontend-content
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
      volumes:
      - name: nginx-config
        configMap:
          name: frontend-config
      - name: frontend-content
        configMap:
          name: frontend-config

---
# Frontend Service
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  labels:
    app: frontend
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
    name: http
  type: ClusterIP
```

## Step 5: Database Initialization

Create `db-init-job.yaml`:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-init
spec:
  template:
    spec:
      containers:
      - name: db-init
        image: mysql:8.0
        command:
        - /bin/sh
        - -c
        - |
          # Wait for MySQL to be ready
          until mysql -h mysql-service -u todouser -ptodopassword123 -e "SELECT 1"; do
            echo "Waiting for MySQL to be ready..."
            sleep 5
          done
          
          # Create tables
          mysql -h mysql-service -u todouser -ptodopassword123 todoapp << 'EOF'
          CREATE TABLE IF NOT EXISTS todos (
            id INT AUTO_INCREMENT PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            description TEXT,
            completed BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
          );
          
          -- Insert sample data
          INSERT IGNORE INTO todos (id, title, description, completed) VALUES
          (1, 'Setup Kubernetes cluster', 'Configure minikube and install kubectl', true),
          (2, 'Deploy multi-tier application', 'Deploy frontend, backend, and database', false),
          (3, 'Configure monitoring', 'Set up health checks and monitoring', false),
          (4, 'Add security measures', 'Implement RBAC and network policies', false);
          EOF
          
          echo "Database initialization completed"
      restartPolicy: OnFailure
  backoffLimit: 5
```

## Step 6: Ingress Configuration

Create `ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: todoapp-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: todoapp.local
    http:
      paths:
      # API routes
      - path: /api(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: backend-service
            port:
              number: 80
      # Frontend routes (default)
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
```

## Step 7: Deployment Script

Create `deploy.sh`:

```bash
#!/bin/bash

echo "Deploying Todo Application to Kubernetes..."

# Enable ingress if not already enabled
echo "Enabling ingress..."
minikube addons enable ingress

# Deploy in order
echo "Deploying database layer..."
kubectl apply -f mysql-deployment.yaml

echo "Deploying cache layer..."
kubectl apply -f redis-deployment.yaml

echo "Waiting for database to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/mysql

echo "Initializing database..."
kubectl apply -f db-init-job.yaml
kubectl wait --for=condition=complete --timeout=300s job/db-init

echo "Deploying backend API..."
kubectl apply -f backend-deployment.yaml

echo "Waiting for backend to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/backend

echo "Deploying frontend..."
kubectl apply -f frontend-deployment.yaml

echo "Waiting for frontend to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/frontend

echo "Deploying ingress..."
kubectl apply -f ingress.yaml

echo "Adding todoapp.local to /etc/hosts..."
echo "$(minikube ip) todoapp.local" | sudo tee -a /etc/hosts

echo "Deployment completed!"
echo "Access the application at: http://todoapp.local"
echo ""
echo "To check status:"
echo "kubectl get pods"
echo "kubectl get services"
echo "kubectl get ingress"
```

## Step 8: Testing and Verification

### Deploy the Complete Application

```bash
# Make deploy script executable
chmod +x deploy.sh

# Deploy everything
./deploy.sh

# Check deployment status
kubectl get pods
kubectl get services
kubectl get ingress
```

### Verify Each Layer

```bash
# Test database connectivity
kubectl run mysql-client --image=mysql:8.0 -it --rm --restart=Never \
  -- mysql -h mysql-service -u todouser -ptodopassword123 -e "SELECT * FROM todoapp.todos;"

# Test cache connectivity
kubectl run redis-client --image=redis:7-alpine -it --rm --restart=Never \
  -- redis-cli -h redis-service ping

# Test backend API
kubectl port-forward service/backend-service 3000:80
# In another terminal: curl http://localhost:3000/api/todos

# Test frontend
kubectl port-forward service/frontend-service 8080:80
# In another terminal: curl http://localhost:8080

# Test complete application via ingress
curl http://todoapp.local
curl http://todoapp.local/api/todos
```

## Application Monitoring

### Monitor All Components

Create `monitor-app.sh`:

```bash
#!/bin/bash

echo "=== Todo Application Status ==="
echo

echo "Pods:"
kubectl get pods -l 'tier in (database,cache,api,presentation)' -o wide

echo -e "\nServices:"
kubectl get services -l 'app in (mysql,redis,backend,frontend)'

echo -e "\nIngress:"
kubectl get ingress todoapp-ingress

echo -e "\nResource Usage:"
kubectl top pods -l 'tier in (database,cache,api,presentation)' 2>/dev/null || echo "Metrics not available"

echo -e "\nStorage:"
kubectl get pvc

echo -e "\nRecent Events:"
kubectl get events --sort-by=.metadata.creationTimestamp | tail -10
```

### Health Check Dashboard

```bash
# Create health check script
cat > check-health.sh << 'EOF'
#!/bin/bash

echo "=== Health Check Dashboard ==="
echo

# Check each component
echo "Database Health:"
kubectl exec deployment/mysql -- mysqladmin ping -u root -prootpassword123 2>/dev/null && echo "✓ MySQL: Healthy" || echo "✗ MySQL: Unhealthy"

echo "Cache Health:"
kubectl exec deployment/redis -- redis-cli ping 2>/dev/null && echo "✓ Redis: Healthy" || echo "✗ Redis: Unhealthy"

echo "Backend Health:"
kubectl exec deployment/backend -- wget -q -O- http://localhost:3000/health 2>/dev/null && echo "✓ Backend: Healthy" || echo "✗ Backend: Unhealthy"

echo "Frontend Health:"
kubectl exec deployment/frontend -- wget -q -O- http://localhost:80/health 2>/dev/null && echo "✓ Frontend: Healthy" || echo "✗ Frontend: Unhealthy"

echo -e "\nApplication URL: http://todoapp.local"
EOF

chmod +x check-health.sh
./check-health.sh
```

## Scaling the Application

### Scale Individual Components

```bash
# Scale backend for higher load
kubectl scale deployment backend --replicas=5

# Scale frontend for better availability
kubectl scale deployment frontend --replicas=3

# Database typically stays at 1 replica for this setup
# (Production would use database clustering)

# Verify scaling
kubectl get deployments
```

### Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## Configuration Management Patterns

### Environment-Specific Configurations

```bash
# Development environment
kubectl create namespace todo-dev
kubectl apply -f mysql-deployment.yaml -n todo-dev
# Use smaller resource limits and different configurations

# Production environment
kubectl create namespace todo-prod
kubectl apply -f mysql-deployment.yaml -n todo-prod
# Use production-grade resources and configurations
```

### External Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-settings
data:
  # Feature flags
  features.json: |
    {
      "enableUserAuth": false,
      "enableAnalytics": true,
      "maxTodosPerUser": 100
    }
  # Application configuration
  app-config.yaml: |
    server:
      port: 3000
      cors:
        enabled: true
        origins: ["*"]
    database:
      pool:
        min: 2
        max: 10
      timeout: 30000
```

## Troubleshooting Multi-Tier Applications

### Common Issues and Solutions

#### 1. Service Discovery Problems

```bash
# Test DNS resolution between services
kubectl run debug --image=busybox -it --rm -- nslookup mysql-service

# Check service endpoints
kubectl get endpoints mysql-service backend-service
```

#### 2. Database Connection Issues

```bash
# Check database logs
kubectl logs deployment/mysql

# Test connection from backend
kubectl exec deployment/backend -- nc -zv mysql-service 3306
```

#### 3. API Communication Problems

```bash
# Check backend logs
kubectl logs deployment/backend

# Test API directly
kubectl port-forward service/backend-service 3000:80
curl http://localhost:3000/api/todos
```

#### 4. Frontend Not Loading

```bash
# Check nginx configuration
kubectl describe configmap frontend-config

# Check frontend logs
kubectl logs deployment/frontend

# Test static content serving
kubectl port-forward service/frontend-service 8080:80
```

## Security Considerations

### Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-netpol
spec:
  podSelector:
    matchLabels:
      app: mysql
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 3306
```

### Secret Management

```bash
# Use external secret management
kubectl create secret generic app-secrets \
  --from-literal=db-password="$(openssl rand -base64 32)" \
  --from-literal=jwt-secret="$(openssl rand -base64 64)"
```

## Performance Optimization

### Resource Optimization

```yaml
# Right-size resources based on actual usage
resources:
  requests:
    memory: "64Mi"    # Minimum needed
    cpu: "50m"        # Minimum needed
  limits:
    memory: "128Mi"   # Maximum allowed
    cpu: "200m"       # Maximum allowed
```

### Caching Strategy

```yaml
# Add caching headers in nginx
location /api/ {
    proxy_pass http://backend;
    proxy_cache_valid 200 5m;
    add_header X-Cache-Status $upstream_cache_status;
}
```

## Backup and Recovery

### Database Backup

```bash
# Create backup job
kubectl create job mysql-backup-$(date +%Y%m%d) \
  --image=mysql:8.0 \
  -- mysqldump -h mysql-service -u todouser -ptodopassword123 todoapp
```

## Key Takeaways

1. **Layer separation** - Each tier has specific responsibilities and can scale independently
2. **Service discovery** - Use Kubernetes DNS for communication between services
3. **Configuration management** - Externalize configuration using ConfigMaps and Secrets
4. **Health checks** - Implement proper health checks for each component
5. **Gradual deployment** - Deploy dependencies first, then dependent services
6. **Monitoring** - Monitor each layer and the application as a whole
7. **Security** - Implement network policies and proper secret management

## Cleaning Up

```bash
# Delete the application
kubectl delete -f ingress.yaml
kubectl delete -f frontend-deployment.yaml
kubectl delete -f backend-deployment.yaml
kubectl delete -f db-init-job.yaml
kubectl delete -f redis-deployment.yaml
kubectl delete -f mysql-deployment.yaml

# Remove from /etc/hosts
sudo sed -i '/todoapp.local/d' /etc/hosts

# Delete PVC (this will delete the PV and data)
kubectl delete pvc mysql-pvc
```

## Commands Reference

| Command | Purpose |
|---------|---------|
| `kubectl apply -f .` | Deploy all YAML files in directory |
| `kubectl wait --for=condition=available deployment/<name>` | Wait for deployment |
| `kubectl port-forward service/<name> <local>:<remote>` | Test service locally |
| `kubectl exec deployment/<name> -- <command>` | Execute command in deployment |
| `kubectl scale deployment <name> --replicas=<n>` | Scale deployment |
| `kubectl top pods -l <selector>` | Resource usage by label |

---

**Next Chapter**: [CI/CD with Kubernetes](../12-cicd/) - Learn automated deployment pipelines and GitOps basics.