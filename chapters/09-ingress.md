# Chapter 9: Ingress and Load Balancing

## Learning Objectives

By the end of this chapter, you will understand:
- What Ingress is and how it differs from Services
- How to set up Ingress controllers in minikube
- Path-based and host-based routing
- TLS/SSL termination with Ingress
- Advanced Ingress features and annotations
- Load balancing strategies

## The Problem: External Access to Services

So far, we've used Services to expose applications:
- **ClusterIP**: Internal access only
- **NodePort**: External access via node IP and high port (30000-32767)
- **LoadBalancer**: External IP (cloud provider dependent)

**Problems with these approaches**:
1. **Port limitations**: NodePort uses non-standard ports
2. **No path-based routing**: Can't route different paths to different services
3. **No SSL termination**: Each service handles its own certificates
4. **No host-based routing**: Can't use different domains for different services
5. **Cost**: Multiple LoadBalancers can be expensive

## What is Ingress?

**Ingress** is a Kubernetes resource that manages external access to services in a cluster, typically HTTP/HTTPS. It provides:

1. **Path-based routing**: Route different URLs to different services
2. **Host-based routing**: Route different domains to different services
3. **SSL/TLS termination**: Handle certificates centrally
4. **Load balancing**: Distribute traffic across service endpoints
5. **Single entry point**: One external IP for multiple services

### Ingress vs Service

```
Internet → Ingress Controller → Ingress Rules → Services → Pods
```

- **Service**: Internal load balancing and discovery
- **Ingress**: External routing and access control

## Ingress Controller

An **Ingress Controller** is the component that actually implements Ingress rules. Popular controllers include:
- **NGINX Ingress Controller**
- **Traefik**
- **HAProxy**
- **Ambassador**
- **Istio Gateway**

### Setting up NGINX Ingress in minikube

```bash
# Enable NGINX Ingress addon in minikube
minikube addons enable ingress

# Verify the ingress controller is running
kubectl get pods -n ingress-nginx

# Check the ingress class
kubectl get ingressclass
```

Wait for the ingress controller pods to be ready:

```bash
# Watch until pods are running
kubectl get pods -n ingress-nginx -w
```

## Your First Ingress

Let's create a simple web application and expose it via Ingress.

### Step 1: Create Applications

Create `web-apps.yaml`:

```yaml
# App 1: Hello World
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
      - name: hello-world
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080

---
apiVersion: v1
kind: Service
metadata:
  name: hello-world-service
spec:
  selector:
    app: hello-world
  ports:
  - port: 80
    targetPort: 8080

---
# App 2: Hello Kubernetes
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-kubernetes
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-kubernetes
  template:
    metadata:
      labels:
        app: hello-kubernetes
    spec:
      containers:
      - name: hello-kubernetes
        image: gcr.io/google-samples/hello-app:2.0
        ports:
        - containerPort: 8080

---
apiVersion: v1
kind: Service
metadata:
  name: hello-kubernetes-service
spec:
  selector:
    app: hello-kubernetes
  ports:
  - port: 80
    targetPort: 8080
```

```bash
# Deploy the applications
kubectl apply -f web-apps.yaml

# Verify deployments and services
kubectl get deployments
kubectl get services
```

### Step 2: Create Basic Ingress

Create `basic-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: basic-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /hello-world
        pathType: Prefix
        backend:
          service:
            name: hello-world-service
            port:
              number: 80
      - path: /hello-kubernetes
        pathType: Prefix
        backend:
          service:
            name: hello-kubernetes-service
            port:
              number: 80
```

```bash
# Create the ingress
kubectl apply -f basic-ingress.yaml

# Check ingress status
kubectl get ingress
kubectl describe ingress basic-ingress
```

### Step 3: Test the Ingress

```bash
# Get minikube IP
minikube ip

# Test the routes (replace <minikube-ip> with actual IP)
curl http://<minikube-ip>/hello-world
curl http://<minikube-ip>/hello-kubernetes

# Or use minikube tunnel for localhost access
minikube tunnel
# In another terminal:
curl http://localhost/hello-world
curl http://localhost/hello-kubernetes
```

## Path-Based Routing

Path-based routing directs traffic based on the URL path.

### Path Types

1. **Exact**: Matches the path exactly
2. **Prefix**: Matches based on URL path prefix

Create `path-routing.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-routing
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      # Exact match
      - path: /api/v1/health
        pathType: Exact
        backend:
          service:
            name: health-service
            port:
              number: 80
      # Prefix match with path rewriting
      - path: /api/v1(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
      # Static content
      - path: /static
        pathType: Prefix
        backend:
          service:
            name: static-service
            port:
              number: 80
      # Default backend
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
```

## Host-Based Routing

Host-based routing directs traffic based on the hostname.

Create `host-routing.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: host-routing
spec:
  ingressClassName: nginx
  rules:
  # Main website
  - host: example.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: website-service
            port:
              number: 80
  # API subdomain
  - host: api.example.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
  # Admin subdomain
  - host: admin.example.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-service
            port:
              number: 80
```

To test host-based routing locally, add entries to `/etc/hosts`:

```bash
# Get minikube IP
minikube ip

# Add to /etc/hosts (replace <minikube-ip>)
echo "<minikube-ip> example.local api.example.local admin.example.local" | sudo tee -a /etc/hosts

# Test different hosts
curl http://example.local/
curl http://api.example.local/
curl http://admin.example.local/
```

## TLS/SSL Termination

Ingress can handle SSL/TLS certificates for secure HTTPS connections.

### Step 1: Create TLS Secret

```bash
# Generate self-signed certificate for testing
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=example.local/O=example.local"

# Create TLS secret
kubectl create secret tls example-tls \
  --key tls.key --cert tls.crt

# Clean up certificate files
rm tls.key tls.crt
```

### Step 2: Create HTTPS Ingress

Create `tls-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - example.local
    - api.example.local
    secretName: example-tls
  rules:
  - host: example.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-world-service
            port:
              number: 80
  - host: api.example.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-kubernetes-service
            port:
              number: 80
```

```bash
# Apply TLS ingress
kubectl apply -f tls-ingress.yaml

# Test HTTPS (ignore certificate warnings for self-signed cert)
curl -k https://example.local/
curl -k https://api.example.local/
```

## Advanced Ingress Features

### 1. Custom Error Pages

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: custom-errors
  annotations:
    nginx.ingress.kubernetes.io/custom-http-errors: "404,503"
    nginx.ingress.kubernetes.io/default-backend: error-pages-service
spec:
  # ... ingress rules
```

### 2. Rate Limiting

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rate-limited
  annotations:
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
spec:
  # ... ingress rules
```

### 3. Basic Authentication

```bash
# Create htpasswd file
htpasswd -c auth admin
kubectl create secret generic basic-auth --from-file=auth
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: basic-auth
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required'
spec:
  # ... ingress rules
```

### 4. CORS Headers

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cors-enabled
  annotations:
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://example.com"
    nginx.ingress.kubernetes.io/cors-allow-methods: "PUT, GET, POST, OPTIONS"
spec:
  # ... ingress rules
```

### 5. Request/Response Modification

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: header-modification
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Custom-Header: MyValue";
      more_set_headers "X-Request-ID: $request_id";
spec:
  # ... ingress rules
```

## Complete Multi-Service Example

Let's create a complete example with multiple services behind a single Ingress.

### Step 1: Create Multiple Services

Create `multi-service-app.yaml`:

```yaml
# Frontend Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:1.21
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80

---
# API Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080

---
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 8080

---
# Admin Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: admin
  template:
    metadata:
      labels:
        app: admin
    spec:
      containers:
      - name: admin
        image: gcr.io/google-samples/hello-app:2.0
        ports:
        - containerPort: 8080

---
apiVersion: v1
kind: Service
metadata:
  name: admin-service
spec:
  selector:
    app: admin
  ports:
  - port: 80
    targetPort: 8080
```

### Step 2: Create Comprehensive Ingress

Create `comprehensive-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: comprehensive-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: nginx
  rules:
  # Main domain
  - host: myapp.local
    http:
      paths:
      # API routes
      - path: /api(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
      # Admin routes (could add auth here)
      - path: /admin(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: admin-service
            port:
              number: 80
      # Frontend (default)
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
  # API subdomain
  - host: api.myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
  # Admin subdomain with basic auth
  - host: admin.myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-service
            port:
              number: 80
```

### Step 3: Deploy and Test

```bash
# Deploy applications
kubectl apply -f multi-service-app.yaml

# Deploy ingress
kubectl apply -f comprehensive-ingress.yaml

# Add hosts to /etc/hosts
echo "$(minikube ip) myapp.local api.myapp.local admin.myapp.local" | sudo tee -a /etc/hosts

# Test different routes
curl http://myapp.local/
curl http://myapp.local/api/
curl http://myapp.local/admin/
curl http://api.myapp.local/
curl http://admin.myapp.local/
```

## Load Balancing Strategies

### 1. Default Round-Robin

The default NGINX behavior distributes requests evenly.

### 2. Session Affinity

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sticky-sessions
  annotations:
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/affinity-mode: "persistent"
    nginx.ingress.kubernetes.io/session-cookie-name: "INGRESSCOOKIE"
    nginx.ingress.kubernetes.io/session-cookie-expires: "86400"
    nginx.ingress.kubernetes.io/session-cookie-max-age: "86400"
spec:
  # ... ingress rules
```

### 3. Weighted Load Balancing

```yaml
# Service A (70% traffic)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: canary-main
  annotations:
    nginx.ingress.kubernetes.io/canary: "false"
spec:
  # ... main service rules

---
# Service B (30% traffic)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: canary-test
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "30"
spec:
  # ... canary service rules
```

## Monitoring and Observability

### Ingress Metrics

```bash
# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Check ingress status
kubectl get ingress -o wide
kubectl describe ingress <ingress-name>

# Check backend service health
kubectl get endpoints
```

### Custom Monitoring

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: monitored-ingress
  annotations:
    nginx.ingress.kubernetes.io/enable-access-log: "true"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      access_log /var/log/nginx/access.log main;
spec:
  # ... ingress rules
```

## Troubleshooting Ingress

### Common Issues

#### 1. Ingress Controller Not Running

```bash
# Check ingress controller pods
kubectl get pods -n ingress-nginx

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

#### 2. DNS Resolution

```bash
# Verify /etc/hosts entries
cat /etc/hosts | grep -E "(example|myapp)\.local"

# Test DNS if using real domains
nslookup example.com
```

#### 3. Backend Service Issues

```bash
# Check service endpoints
kubectl get endpoints <service-name>

# Test service directly
kubectl port-forward service/<service-name> 8080:80
curl http://localhost:8080
```

#### 4. Certificate Issues

```bash
# Check TLS secret
kubectl describe secret <tls-secret-name>

# Verify certificate
kubectl get secret <tls-secret-name> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text
```

## Best Practices

### 1. Use Meaningful Names

```yaml
metadata:
  name: webapp-production-ingress
  annotations:
    description: "Production ingress for web application"
```

### 2. Organize by Environment

```yaml
# Production
metadata:
  name: webapp-prod-ingress
  namespace: production

# Staging  
metadata:
  name: webapp-staging-ingress
  namespace: staging
```

### 3. Security Annotations

```yaml
annotations:
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
  nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  nginx.ingress.kubernetes.io/hsts: "true"
  nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
```

### 4. Resource Limits

```yaml
annotations:
  nginx.ingress.kubernetes.io/proxy-body-size: "10m"
  nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
```

## Cleaning Up

```bash
# Delete ingress resources
kubectl delete ingress basic-ingress comprehensive-ingress

# Delete applications
kubectl delete -f multi-service-app.yaml
kubectl delete -f web-apps.yaml

# Delete TLS secrets
kubectl delete secret example-tls

# Remove hosts from /etc/hosts
sudo sed -i '/\.local/d' /etc/hosts

# Disable ingress addon (optional)
minikube addons disable ingress
```

## Key Takeaways

1. **Ingress provides HTTP/HTTPS routing** - More sophisticated than basic Services
2. **Ingress Controller is required** - Implements the actual routing logic
3. **Path and host-based routing** - Route traffic based on URL paths or domains
4. **TLS termination** - Handle SSL certificates centrally
5. **Advanced features** - Authentication, rate limiting, CORS, etc.
6. **Cost-effective** - Single load balancer for multiple services
7. **Production-ready** - Supports monitoring, logging, and security features

## Commands Reference

| Command | Purpose |
|---------|---------|
| `minikube addons enable ingress` | Enable NGINX Ingress controller |
| `kubectl get ingress` | List Ingress resources |
| `kubectl describe ingress <name>` | Ingress details |
| `kubectl create secret tls <name> --key=<key> --cert=<cert>` | Create TLS secret |
| `kubectl get ingressclass` | List Ingress classes |
| `kubectl logs -n ingress-nginx deployment/ingress-nginx-controller` | Controller logs |
| `minikube tunnel` | Enable LoadBalancer access |
| `kubectl delete ingress <name>` | Delete Ingress |

---

**Next Chapter**: [Health Checks and Monitoring](../10-monitoring/) - Learn how to ensure application reliability and observability in Kubernetes.