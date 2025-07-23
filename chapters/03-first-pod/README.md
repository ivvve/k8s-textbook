# Chapter 3: Your First Pod

## Learning Objectives

By the end of this chapter, you will understand:
- What a Pod is and why it's important
- The relationship between containers and Pods
- How to create, inspect, and manage Pods
- Pod lifecycle and states
- Common Pod patterns and best practices

## What is a Pod?

A **Pod** is the smallest deployable unit in Kubernetes. Think of it as a "wrapper" around one or more containers that need to work closely together.

### Key Characteristics of Pods

1. **Shared Network**: All containers in a Pod share the same IP address and port space
2. **Shared Storage**: Containers can share volumes mounted to the Pod
3. **Atomic Unit**: Pods are created and destroyed as a single unit
4. **Single Host**: All containers in a Pod run on the same node

### Pod vs Container Analogy

If you think of containers as individual applications:
- A **container** is like a single program running on your computer
- A **Pod** is like a shared workspace where related programs can collaborate

## Why Pods Instead of Just Containers?

### The Problem with Bare Containers
Imagine you have a web application that needs:
- A main web server container
- A logging sidecar container
- Shared file storage between them

Without Pods, you'd need to:
- Manually coordinate networking between containers
- Manage shared storage separately
- Handle container lifecycle dependencies

### The Pod Solution
A Pod provides:
- **Automatic networking**: Containers can communicate via `localhost`
- **Shared volumes**: Easy file sharing between containers
- **Coordinated lifecycle**: All containers start and stop together

## Your First Pod: Running nginx

Let's create your first Pod running an nginx web server.

### Method 1: Using kubectl run (Imperative)

```bash
# Create a Pod running nginx
kubectl run my-nginx --image=nginx:1.21

# Check if it's running
kubectl get pods

# Get detailed information
kubectl describe pod my-nginx
```

### Expected Output

```bash
$ kubectl get pods
NAME       READY   STATUS    RESTARTS   AGE
my-nginx   1/1     Running   0          30s
```

### Method 2: Using YAML Declaration (Declarative)

Create a file called `nginx-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-nginx-yaml
  labels:
    app: nginx
    version: "1.21"
spec:
  containers:
  - name: nginx
    image: nginx:1.21
    ports:
    - containerPort: 80
```

Apply the YAML file:

```bash
# Create Pod from YAML
kubectl apply -f nginx-pod.yaml

# Verify it's running
kubectl get pods
```

## Understanding Pod YAML Structure

Let's break down the YAML file:

```yaml
apiVersion: v1          # Kubernetes API version for Pods
kind: Pod              # Type of Kubernetes object
metadata:              # Information about the Pod
  name: my-nginx-yaml  # Pod name (must be unique in namespace)
  labels:              # Key-value pairs for identification
    app: nginx
    version: "1.21"
spec:                  # Desired state specification
  containers:          # List of containers in the Pod
  - name: nginx        # Container name
    image: nginx:1.21  # Container image
    ports:             # Ports the container exposes
    - containerPort: 80
```

## Inspecting Your Pod

### Basic Information

```bash
# List all pods
kubectl get pods

# Get more details
kubectl get pods -o wide

# Show labels
kubectl get pods --show-labels
```

### Detailed Description

```bash
# Detailed Pod information
kubectl describe pod my-nginx

# Get Pod in YAML format
kubectl get pod my-nginx -o yaml
```

### Viewing Logs

```bash
# View container logs
kubectl logs my-nginx

# Follow logs in real-time
kubectl logs -f my-nginx

# View previous container logs (if container restarted)
kubectl logs my-nginx --previous
```

## Accessing Your Pod

### Method 1: Port Forwarding

```bash
# Forward local port 8080 to Pod port 80
kubectl port-forward my-nginx 8080:80

# In another terminal, test it
curl http://localhost:8080
# Or open http://localhost:8080 in your browser
```

### Method 2: Executing Commands in the Pod

```bash
# Execute a command in the Pod
kubectl exec my-nginx -- nginx -v

# Get an interactive shell
kubectl exec -it my-nginx -- /bin/bash

# Inside the container, you can explore:
# ls /usr/share/nginx/html/
# curl localhost
# exit
```

## Pod Lifecycle and States

### Pod Phases

1. **Pending**: Pod accepted but not yet running
2. **Running**: Pod bound to node and at least one container is running
3. **Succeeded**: All containers terminated successfully
4. **Failed**: All containers terminated, at least one failed
5. **Unknown**: Pod state cannot be determined

### Container States

1. **Waiting**: Container is not running (pulling image, waiting for dependencies)
2. **Running**: Container is executing
3. **Terminated**: Container finished execution

### Checking Pod Status

```bash
# Quick status check
kubectl get pods

# Detailed status
kubectl describe pod my-nginx

# Watch status changes in real-time
kubectl get pods -w
```

## Multi-Container Pod Example

Let's create a Pod with two containers that work together:

Create `multi-container-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
spec:
  containers:
  - name: nginx
    image: nginx:1.21
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
  
  - name: log-reader
    image: busybox
    command: ["sh", "-c", "while true; do tail -f /var/log/nginx/access.log; sleep 10; done"]
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
  
  volumes:
  - name: shared-logs
    emptyDir: {}
```

```bash
# Create the multi-container Pod
kubectl apply -f multi-container-pod.yaml

# Check both containers are running
kubectl get pods

# View logs from the log-reader container
kubectl logs multi-container-pod -c log-reader

# Generate some traffic to create logs
kubectl port-forward multi-container-pod 8080:80
# In another terminal: curl http://localhost:8080
```

### Understanding the Multi-Container Example

- **nginx container**: Serves web pages and writes access logs
- **log-reader container**: Reads and displays the nginx access logs
- **shared volume**: Both containers can access the same log directory
- **Communication**: They communicate through shared storage

## Common Pod Patterns

### 1. Sidecar Pattern
Helper container that extends the main container's functionality:
```yaml
# Main app container + logging sidecar
# Main app container + monitoring agent
# Main app container + configuration updater
```

### 2. Adapter Pattern
Container that transforms data for the main container:
```yaml
# Main app + data format converter
# Main app + legacy protocol adapter
```

### 3. Ambassador Pattern
Container that acts as a proxy for the main container:
```yaml
# Main app + database proxy
# Main app + service mesh proxy
```

## Pod Best Practices

### 1. Single Responsibility
- Usually one main container per Pod
- Add sidecars only when necessary
- Keep Pods focused on a single concern

### 2. Resource Management
```yaml
spec:
  containers:
  - name: nginx
    image: nginx:1.21
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

### 3. Health Checks
```yaml
spec:
  containers:
  - name: nginx
    image: nginx:1.21
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 30
      periodSeconds: 10
```

### 4. Proper Labels
```yaml
metadata:
  labels:
    app: my-app
    version: "1.0"
    environment: development
    component: frontend
```

## Troubleshooting Common Pod Issues

### Pod Stuck in Pending
```bash
# Check events
kubectl describe pod <pod-name>

# Common causes:
# - Insufficient resources
# - Image pull errors
# - Volume mount issues
```

### Pod Crashing (CrashLoopBackOff)
```bash
# Check logs
kubectl logs <pod-name>
kubectl logs <pod-name> --previous

# Common causes:
# - Application errors
# - Missing configuration
# - Resource limits too low
```

### Cannot Access Pod
```bash
# Check if Pod is running
kubectl get pods

# Check services (covered in next chapter)
kubectl get services

# Try port-forward for testing
kubectl port-forward <pod-name> 8080:80
```

## Cleaning Up

```bash
# Delete individual Pods
kubectl delete pod my-nginx
kubectl delete pod my-nginx-yaml
kubectl delete pod multi-container-pod

# Delete all Pods (be careful!)
kubectl delete pods --all
```

## Hands-On Exercises

### Exercise 1: Create a Custom Web Server Pod
1. Create a Pod running Apache HTTP server (`httpd:2.4`)
2. Use port-forward to access it
3. Check the default Apache page

### Exercise 2: Multi-Container Communication
1. Create a Pod with two containers
2. One container writes data to a shared volume
3. Another container reads and processes that data

### Exercise 3: Pod Troubleshooting
1. Create a Pod with a non-existent image
2. Observe the error state
3. Fix the image and redeploy

## Key Takeaways

1. **Pods are the atomic unit** - smallest deployable unit in Kubernetes
2. **Usually one container per Pod** - unless containers need tight coupling
3. **Shared networking and storage** - containers in a Pod can easily communicate
4. **Ephemeral by nature** - Pods can be created and destroyed freely
5. **Declarative configuration** - YAML files are preferred over imperative commands

## Commands Reference

| Command | Purpose |
|---------|---------|
| `kubectl run <name> --image=<image>` | Create Pod imperatively |
| `kubectl apply -f <file>` | Create Pod from YAML |
| `kubectl get pods` | List Pods |
| `kubectl describe pod <name>` | Detailed Pod information |
| `kubectl logs <name>` | View container logs |
| `kubectl exec -it <name> -- <command>` | Execute command in Pod |
| `kubectl port-forward <name> <local>:<remote>` | Forward ports |
| `kubectl delete pod <name>` | Delete Pod |

---

**Next Chapter**: [Services and Networking](../04-services/) - Learn how to expose your Pods and enable communication between different parts of your application.