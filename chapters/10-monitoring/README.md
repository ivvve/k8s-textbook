# Chapter 10: Health Checks and Monitoring

## Learning Objectives

By the end of this chapter, you will understand:
- The importance of health checks in Kubernetes
- Different types of probes (liveness, readiness, startup)
- How to implement effective health checks
- Basic monitoring with kubectl and built-in tools
- Application observability patterns
- Troubleshooting unhealthy applications

## The Problem: Application Health and Reliability

In production environments, applications can fail in various ways:

1. **Silent failures**: Application appears running but doesn't respond to requests
2. **Slow startup**: Application takes time to initialize
3. **Temporary unavailability**: Application needs time to recover from errors
4. **Resource exhaustion**: Application becomes unresponsive due to memory/CPU issues
5. **Dependency failures**: Application fails when external services are unavailable

Without proper health checks, Kubernetes cannot:
- Know when to restart failing containers
- Route traffic only to healthy pods
- Perform zero-downtime deployments safely

## Health Check Overview

Kubernetes provides three types of health probes:

### 1. Liveness Probe
**Purpose**: Determines if a container is running properly
**Action**: Restarts the container if the probe fails
**Use case**: Detect deadlocks, infinite loops, or crashed applications

### 2. Readiness Probe
**Purpose**: Determines if a container is ready to receive traffic
**Action**: Removes the pod from service endpoints if the probe fails
**Use case**: Handle slow startup, temporary unavailability, or dependency issues

### 3. Startup Probe
**Purpose**: Provides additional startup time for slow-starting containers
**Action**: Disables other probes until startup probe succeeds
**Use case**: Legacy applications with long initialization times

## Probe Mechanisms

Kubernetes supports three probe mechanisms:

### 1. HTTP GET Probe
Makes an HTTP GET request to a specified path and port:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
    httpHeaders:
    - name: Custom-Header
      value: Health-Check
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
  successThreshold: 1
```

### 2. TCP Socket Probe
Attempts to open a TCP connection to a specified port:

```yaml
livenessProbe:
  tcpSocket:
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 20
```

### 3. Exec Probe
Executes a command inside the container:

```yaml
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
  initialDelaySeconds: 5
  periodSeconds: 5
```

## Probe Configuration Parameters

### Timing Parameters

- **initialDelaySeconds**: Wait time before first probe
- **periodSeconds**: How often to perform the probe
- **timeoutSeconds**: Timeout for each probe attempt
- **failureThreshold**: Consecutive failures before action
- **successThreshold**: Consecutive successes to consider healthy

### Best Practice Timing

```yaml
# For fast-starting applications
initialDelaySeconds: 10
periodSeconds: 10
timeoutSeconds: 3
failureThreshold: 3

# For slow-starting applications
initialDelaySeconds: 60
periodSeconds: 30
timeoutSeconds: 10
failureThreshold: 3
```

## Implementing Health Checks

### Example 1: Web Application with Health Endpoint

Create `web-app-with-health.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-with-health
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
        ports:
        - containerPort: 80
        # Create a simple health check file
        lifecycle:
          postStart:
            exec:
              command:
              - /bin/sh
              - -c
              - 'echo "healthy" > /usr/share/nginx/html/health'
        # Liveness probe - restart if fails
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        # Readiness probe - remove from service if fails
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
        # Resource limits to prevent resource exhaustion
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
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

```bash
# Deploy the application
kubectl apply -f web-app-with-health.yaml

# Watch the deployment
kubectl get pods -w

# Check pod details to see probe status
kubectl describe pod <pod-name>
```

### Example 2: Database with Custom Health Check

Create `mysql-with-health.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-with-health
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
          value: "rootpassword123"
        - name: MYSQL_DATABASE
          value: "testdb"
        ports:
        - containerPort: 3306
        # Startup probe for slow MySQL initialization
        startupProbe:
          exec:
            command:
            - mysqladmin
            - ping
            - -h
            - localhost
            - -u
            - root
            - -prootpassword123
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 30  # Allow up to 5 minutes for startup
        # Liveness probe
        livenessProbe:
          exec:
            command:
            - mysqladmin
            - ping
            - -h
            - localhost
            - -u
            - root
            - -prootpassword123
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        # Readiness probe
        readinessProbe:
          exec:
            command:
            - mysql
            - -h
            - localhost
            - -u
            - root
            - -prootpassword123
            - -e
            - "SELECT 1"
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"

---
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
```

```bash
# Deploy MySQL with health checks
kubectl apply -f mysql-with-health.yaml

# Watch the startup process
kubectl get pods -w

# Check events to see probe activities
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Testing Health Check Behavior

### Simulating Application Failure

Create `health-test-app.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-test-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: health-test
  template:
    metadata:
      labels:
        app: health-test
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        # Create health endpoint that can be toggled
        lifecycle:
          postStart:
            exec:
              command:
              - /bin/sh
              - -c
              - |
                mkdir -p /usr/share/nginx/html
                echo '<!DOCTYPE html><html><body>' > /usr/share/nginx/html/index.html
                echo '<h1>Health Test App</h1>' >> /usr/share/nginx/html/index.html
                echo '<p>Status: <span id="status">Healthy</span></p>' >> /usr/share/nginx/html/index.html
                echo '<button onclick="toggleHealth()">Toggle Health</button>' >> /usr/share/nginx/html/index.html
                echo '<script>' >> /usr/share/nginx/html/index.html
                echo 'function toggleHealth() {' >> /usr/share/nginx/html/index.html
                echo '  fetch("/toggle-health", {method: "POST"});' >> /usr/share/nginx/html/index.html
                echo '}' >> /usr/share/nginx/html/index.html
                echo '</script></body></html>' >> /usr/share/nginx/html/index.html
                echo "healthy" > /tmp/health-status
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - 'test -f /tmp/health-status'
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 2
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - 'test -f /tmp/health-status'
          initialDelaySeconds: 5
          periodSeconds: 3
          failureThreshold: 1

---
apiVersion: v1
kind: Service
metadata:
  name: health-test-service
spec:
  selector:
    app: health-test
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
```

```bash
# Deploy test application
kubectl apply -f health-test-app.yaml

# Get service URL
minikube service health-test-service --url

# Test health failure simulation
kubectl exec deployment/health-test-app -- rm /tmp/health-status

# Watch pod behavior
kubectl get pods -w

# Check events
kubectl describe pod <pod-name>
```

## Monitoring with kubectl

### Basic Monitoring Commands

```bash
# Check cluster component status
kubectl get componentstatuses

# Monitor node resource usage
kubectl top nodes

# Monitor pod resource usage
kubectl top pods

# Monitor specific namespace
kubectl top pods -n kube-system

# Get detailed resource usage
kubectl describe node <node-name>
```

### Pod Status Monitoring

```bash
# Watch pod status changes
kubectl get pods -w

# Check pod events
kubectl get events --sort-by=.metadata.creationTimestamp

# Monitor specific pod
kubectl describe pod <pod-name>

# Check pod logs
kubectl logs <pod-name> -f

# Check previous container logs (after restart)
kubectl logs <pod-name> --previous
```

### Service Endpoint Monitoring

```bash
# Check service endpoints
kubectl get endpoints

# Monitor service status
kubectl describe service <service-name>

# Test service connectivity
kubectl run test-pod --image=busybox -it --rm -- /bin/sh
# Inside pod: wget -qO- http://<service-name>
```

## Application Metrics and Observability

### Metrics Server Setup

```bash
# Check if metrics-server is running (usually enabled by default in minikube)
kubectl get pods -n kube-system | grep metrics-server

# If not present, enable it in minikube
minikube addons enable metrics-server

# Verify metrics are available
kubectl top nodes
kubectl top pods
```

### Custom Metrics Example

Create `app-with-metrics.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: metrics-demo
  template:
    metadata:
      labels:
        app: metrics-demo
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        - containerPort: 9090  # Metrics port
        # Add a sidecar for metrics collection
      - name: metrics-collector
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            echo "# HELP http_requests_total Total HTTP requests" > /tmp/metrics
            echo "# TYPE http_requests_total counter" >> /tmp/metrics
            echo "http_requests_total $(date +%s)" >> /tmp/metrics
            echo "# HELP app_up Application status" >> /tmp/metrics
            echo "# TYPE app_up gauge" >> /tmp/metrics
            echo "app_up 1" >> /tmp/metrics
            sleep 15
          done
        volumeMounts:
        - name: metrics-volume
          mountPath: /tmp
      volumes:
      - name: metrics-volume
        emptyDir: {}
```

## Logging and Log Monitoring

### Container Logs

```bash
# View logs from all containers in a pod
kubectl logs <pod-name> --all-containers=true

# View logs from specific container
kubectl logs <pod-name> -c <container-name>

# Stream logs
kubectl logs -f <pod-name>

# View logs with timestamps
kubectl logs <pod-name> --timestamps=true

# View last N lines
kubectl logs <pod-name> --tail=50
```

### Log Aggregation Pattern

Create `logging-demo.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logging-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: logging-demo
  template:
    metadata:
      labels:
        app: logging-demo
    spec:
      containers:
      # Main application container
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        volumeMounts:
        - name: log-volume
          mountPath: /var/log/nginx
      # Log processing sidecar
      - name: log-processor
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            if [ -f /var/log/nginx/access.log ]; then
              echo "=== Access Log Summary ==="
              tail -10 /var/log/nginx/access.log | grep -E "(GET|POST)" | wc -l
              echo "Recent requests: $(tail -5 /var/log/nginx/access.log)"
            fi
            sleep 30
          done
        volumeMounts:
        - name: log-volume
          mountPath: /var/log/nginx
      volumes:
      - name: log-volume
        emptyDir: {}
```

## Health Check Best Practices

### 1. Design Effective Health Endpoints

```yaml
# Good: Comprehensive health check
livenessProbe:
  httpGet:
    path: /health/live
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health/ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 2
```

Health endpoints should check:
- Application can process requests
- Critical dependencies are available
- Resource availability (memory, disk space)

### 2. Appropriate Timing Configuration

```yaml
# Fast-starting web application
initialDelaySeconds: 10
periodSeconds: 10
timeoutSeconds: 3

# Database or heavy application
initialDelaySeconds: 60
periodSeconds: 30
timeoutSeconds: 10
```

### 3. Different Probes for Different Purposes

```yaml
# Startup probe for slow initialization
startupProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 30  # Up to 2.5 minutes

# Liveness probe for deadlock detection
livenessProbe:
  httpGet:
    path: /health/live
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3

# Readiness probe for traffic routing
readinessProbe:
  httpGet:
    path: /health/ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 2
```

### 4. Resource Limits and Health Checks

```yaml
spec:
  containers:
  - name: app
    resources:
      requests:
        memory: "128Mi"
        cpu: "250m"
      limits:
        memory: "256Mi"
        cpu: "500m"
    livenessProbe:
      httpGet:
        path: /health
        port: 8080
      # Allow extra time under resource pressure
      timeoutSeconds: 10
      failureThreshold: 5
```

## Troubleshooting Health Check Issues

### Common Problems and Solutions

#### 1. Probe Failing During Startup

```bash
# Check pod events
kubectl describe pod <pod-name>

# Look for "Readiness probe failed" or "Liveness probe failed"
# Solution: Increase initialDelaySeconds or add startupProbe
```

#### 2. Pod Continuously Restarting

```bash
# Check restart count
kubectl get pods

# Check previous container logs
kubectl logs <pod-name> --previous

# Solution: Fix liveness probe or application issue
```

#### 3. Pod Not Receiving Traffic

```bash
# Check service endpoints
kubectl get endpoints <service-name>

# If no endpoints, check readiness probe configuration
kubectl describe pod <pod-name>
```

#### 4. Intermittent Health Check Failures

```bash
# Check resource usage
kubectl top pods

# Check node resources
kubectl describe node <node-name>

# Solution: Adjust resource limits or probe timing
```

## Monitoring Dashboard Setup

### Simple Monitoring Script

Create `monitor.sh`:

```bash
#!/bin/bash

echo "=== Kubernetes Cluster Monitor ==="
echo

echo "Cluster Info:"
kubectl cluster-info

echo -e "\nNode Status:"
kubectl get nodes -o wide

echo -e "\nNamespace Resource Usage:"
kubectl top pods --all-namespaces --sort-by=cpu

echo -e "\nPod Status:"
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

echo -e "\nRecent Events:"
kubectl get events --sort-by=.metadata.creationTimestamp --all-namespaces | tail -10

echo -e "\nService Status:"
kubectl get services --all-namespaces

echo -e "\nIngress Status:"
kubectl get ingress --all-namespaces
```

```bash
# Make executable and run
chmod +x monitor.sh
./monitor.sh
```

## Advanced Health Check Patterns

### 1. Dependency Health Checks

```yaml
readinessProbe:
  exec:
    command:
    - /bin/sh
    - -c
    - |
      # Check database connection
      nc -z mysql-service 3306 &&
      # Check Redis connection  
      nc -z redis-service 6379 &&
      # Check external API
      curl -f http://external-api.com/health
  initialDelaySeconds: 10
  periodSeconds: 30
```

### 2. Graceful Shutdown

```yaml
spec:
  containers:
  - name: app
    image: myapp:latest
    lifecycle:
      preStop:
        exec:
          command:
          - /bin/sh
          - -c
          - |
            # Graceful shutdown
            echo "Shutting down gracefully..."
            # Stop accepting new requests
            rm /tmp/ready
            # Wait for existing requests to complete
            sleep 15
            # Shutdown application
            killall myapp
    terminationGracePeriodSeconds: 30
```

### 3. Circuit Breaker Pattern

```yaml
readinessProbe:
  exec:
    command:
    - /bin/sh
    - -c
    - |
      # Check error rate
      ERROR_RATE=$(curl -s localhost:8080/metrics | grep error_rate | cut -d' ' -f2)
      if [ "$ERROR_RATE" -gt "0.1" ]; then
        exit 1
      fi
      exit 0
  periodSeconds: 10
  failureThreshold: 3
```

## Key Takeaways

1. **Health checks are essential** - Enable self-healing and zero-downtime deployments
2. **Use appropriate probe types** - Liveness for restarts, readiness for traffic routing
3. **Configure timing carefully** - Balance responsiveness with stability
4. **Monitor application metrics** - Use kubectl and metrics-server for basic monitoring
5. **Design comprehensive health endpoints** - Check dependencies and resources
6. **Plan for graceful shutdown** - Handle termination signals properly
7. **Test failure scenarios** - Verify health checks work as expected

## Hands-On Exercises

### Exercise 1: Implement Health Checks

1. Deploy an application without health checks
2. Add liveness and readiness probes
3. Test failure scenarios by simulating app crashes

### Exercise 2: Monitor Application Health

1. Deploy multiple applications with health checks
2. Use kubectl commands to monitor their status
3. Create a simple monitoring script

### Exercise 3: Troubleshoot Health Issues

1. Deploy an application with incorrect health check configuration
2. Identify and fix the issues using kubectl
3. Verify the fixes work correctly

## Cleaning Up

```bash
# Delete deployments
kubectl delete deployment webapp-with-health mysql-with-health health-test-app metrics-demo logging-demo

# Delete services
kubectl delete service webapp-service mysql-service health-test-service

# Clean up any test pods
kubectl delete pod --all --force --grace-period=0
```

## Commands Reference

| Command | Purpose |
|---------|---------|
| `kubectl describe pod <name>` | Check probe status and events |
| `kubectl logs <name> --previous` | View logs from previous container |
| `kubectl top nodes` | Node resource usage |
| `kubectl top pods` | Pod resource usage |
| `kubectl get events --sort-by=.metadata.creationTimestamp` | Recent cluster events |
| `kubectl get endpoints` | Service endpoint status |
| `minikube addons enable metrics-server` | Enable metrics collection |
| `kubectl exec <pod> -- <command>` | Execute health check commands |

---

**Next Chapter**: [Multi-Tier Application Deployment](../11-multi-tier/) - Learn how to deploy complete application stacks in Kubernetes.