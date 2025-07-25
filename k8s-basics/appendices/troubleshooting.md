# Appendix C: Troubleshooting Guide

This guide provides solutions to common Kubernetes and minikube issues you might encounter while working through the textbook.

## minikube Issues

### minikube won't start

#### Error: "Docker is not running"
**Problem**: minikube can't find Docker daemon
**Solution**:
```bash
# Start Docker Desktop (macOS/Windows) or Docker service (Linux)
# macOS: Open Docker Desktop application
# Linux: 
sudo systemctl start docker
sudo systemctl enable docker

# Verify Docker is running
docker version
```

#### Error: "Insufficient resources"
**Problem**: Not enough CPU/memory allocated
**Solution**:
```bash
# Stop minikube if running
minikube stop

# Start with more resources
minikube start --cpus=4 --memory=4096

# Or delete and recreate
minikube delete
minikube start --cpus=4 --memory=4096
```

#### Error: "Driver issues" or "Hypervisor not found"
**Problem**: Container/VM driver not available
**Solution**:
```bash
# Try different drivers
minikube start --driver=docker
minikube start --driver=virtualbox
minikube start --driver=hyperkit  # macOS only

# List available drivers
minikube start --help | grep driver
```

#### Error: "Port already in use"
**Problem**: Port conflicts with existing services
**Solution**:
```bash
# Delete existing minikube cluster
minikube delete

# Start fresh
minikube start

# Or find and kill process using the port
# macOS/Linux:
lsof -i :8443
sudo kill -9 <PID>
```

### minikube cluster not accessible

#### Error: "Unable to connect to server"
**Problem**: kubectl can't reach minikube API server
**Solution**:
```bash
# Check minikube status
minikube status

# Restart minikube
minikube stop
minikube start

# Update kubectl context
minikube update-context

# Verify connection
kubectl cluster-info
```

## Pod Issues

### Pod stuck in Pending state

#### Check node resources
```bash
kubectl describe pod <pod-name>
kubectl describe nodes
kubectl top nodes  # Requires metrics-server
```

**Common causes and solutions**:
- **Insufficient CPU/memory**: Reduce resource requests or add more nodes
- **Image pull errors**: Check image name and registry access
- **Volume mount issues**: Verify PVC exists and is bound

#### Error: "ImagePullBackOff"
**Problem**: Cannot pull container image
**Solution**:
```bash
# Check image name and tag
kubectl describe pod <pod-name>

# Try pulling image locally
docker pull <image-name>

# Common fixes:
# 1. Correct image name/tag
# 2. Use public registry for testing
# 3. Add imagePullSecrets for private registries
```

### Pod in CrashLoopBackOff state

#### Check application logs
```bash
kubectl logs <pod-name>
kubectl logs <pod-name> --previous

# For multi-container pods
kubectl logs <pod-name> -c <container-name>
```

**Common causes and solutions**:
- **Application startup errors**: Fix application configuration
- **Missing environment variables**: Add required env vars
- **Health check failures**: Adjust probe settings
- **Resource limits too low**: Increase memory/CPU limits

#### Debug with interactive shell
```bash
# Get shell in running container
kubectl exec -it <pod-name> -- /bin/bash

# Or run debug container
kubectl run debug --image=busybox -it --rm -- /bin/sh
```

### Pod cannot be deleted

#### Pod stuck in Terminating state
**Solution**:
```bash
# Force delete pod
kubectl delete pod <pod-name> --force --grace-period=0

# If that doesn't work, edit the pod to remove finalizers
kubectl patch pod <pod-name> -p '{"metadata":{"finalizers":null}}'
```

## Service and Networking Issues

### Service not accessible

#### Check service configuration
```bash
kubectl get services
kubectl describe service <service-name>
kubectl get endpoints <service-name>
```

#### Verify pod labels match service selector
```bash
kubectl get pods --show-labels
kubectl describe service <service-name> | grep Selector
```

#### Test connectivity from inside cluster
```bash
# Create test pod
kubectl run test-pod --image=busybox -it --rm -- /bin/sh

# Inside the pod, test connectivity
nslookup <service-name>
wget -qO- http://<service-name>:<port>
```

### Port forwarding not working

```bash
# Check if pod is running
kubectl get pods

# Verify port numbers
kubectl describe pod <pod-name>

# Try different local port
kubectl port-forward <pod-name> 8081:80

# Check for port conflicts
lsof -i :<local-port>
```

## Storage Issues

### PVC stuck in Pending state

```bash
kubectl describe pvc <pvc-name>
kubectl get storageclass
```

**Common solutions**:
- **No storage class**: Create or specify storage class
- **Insufficient storage**: Reduce PVC size or add storage
- **Access mode conflicts**: Check supported access modes

### Volume mount failures

```bash
kubectl describe pod <pod-name>
kubectl get pv,pvc
```

**Check for**:
- PVC exists and is bound
- Volume path permissions
- Node storage availability

## Resource and Permission Issues

### Insufficient RBAC permissions

#### Error: "User cannot perform action"
```bash
# Check current user
kubectl auth whoami

# Check permissions
kubectl auth can-i <verb> <resource>
kubectl auth can-i create pods

# Describe role bindings
kubectl describe rolebinding
kubectl describe clusterrolebinding
```

### Resource quota exceeded

```bash
kubectl describe quota
kubectl get limitrange
kubectl top pods
```

**Solutions**:
- Reduce resource requests
- Delete unused resources
- Increase quotas (if you have permissions)

## Application Debugging

### Debug running containers

```bash
# Get shell in container
kubectl exec -it <pod-name> -- /bin/bash

# Check processes
kubectl exec <pod-name> -- ps aux

# Check networking
kubectl exec <pod-name> -- netstat -tulpn

# Check files
kubectl exec <pod-name> -- ls -la /path/to/files
```

### Debug with sidecar containers

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: debug-pod
spec:
  containers:
  - name: main
    image: your-image
  - name: debug
    image: busybox
    command: ["sleep", "3600"]
```

## DNS Resolution Issues

### Test DNS from inside cluster

```bash
# Create test pod
kubectl run dns-test --image=busybox -it --rm -- /bin/sh

# Test DNS resolution
nslookup kubernetes.default
nslookup <service-name>.<namespace>.svc.cluster.local

# Check DNS configuration
cat /etc/resolv.conf
```

### Common DNS issues

- **CoreDNS not running**: Check kube-system pods
- **Service name typos**: Verify service names
- **Wrong namespace**: Use FQDN for cross-namespace access

## Performance Issues

### Check resource usage

```bash
kubectl top nodes
kubectl top pods
kubectl top pods --containers
```

### Identify resource bottlenecks

```bash
# Check node conditions
kubectl describe nodes

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Monitor resource usage over time
kubectl top pods -w
```

## Configuration Issues

### ConfigMap/Secret not updating

```bash
# Check if ConfigMap/Secret exists
kubectl get cm,secrets

# Verify mounting
kubectl describe pod <pod-name>

# Restart pods to pick up changes
kubectl rollout restart deployment <deployment-name>
```

### Environment variable issues

```bash
# Check environment variables in pod
kubectl exec <pod-name> -- env

# Debug configuration
kubectl describe pod <pod-name>
```

## Cluster-Level Issues

### API server not responding

```bash
# Check component status
kubectl get componentstatuses

# Check system pods
kubectl get pods -n kube-system

# Restart minikube
minikube stop
minikube start
```

### etcd issues

```bash
# Check etcd pod
kubectl get pods -n kube-system | grep etcd

# Check etcd logs
kubectl logs -n kube-system <etcd-pod-name>
```

## General Debugging Workflow

### 1. Gather Information
```bash
kubectl get all
kubectl describe <resource-type> <resource-name>
kubectl logs <pod-name>
kubectl get events
```

### 2. Check Resource Status
```bash
kubectl get pods -o wide
kubectl top nodes
kubectl top pods
```

### 3. Examine Configuration
```bash
kubectl get <resource> -o yaml
kubectl explain <resource-type>
```

### 4. Test Connectivity
```bash
kubectl run test --image=busybox -it --rm -- /bin/sh
kubectl port-forward <pod-name> 8080:80
```

### 5. Check Logs and Events
```bash
kubectl logs <pod-name> --previous
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Debugging Tools and Techniques

### Useful debugging images
- `busybox`: Basic utilities and shell
- `nicolaka/netshoot`: Network debugging tools
- `alpine`: Lightweight with package manager
- `ubuntu`: Full-featured debugging environment

### Debugging commands in containers
```bash
# Network debugging
curl, wget, netstat, ss, ping, nslookup, dig

# Process debugging
ps, top, htop, strace

# File system debugging
ls, cat, tail, find, df, du

# System debugging
env, mount, lsof, netstat
```

## When to Restart minikube

Restart minikube when you encounter:
- Persistent networking issues
- Storage mounting problems
- API server connectivity issues
- Corrupted cluster state
- Resource allocation changes needed

```bash
minikube stop
minikube start
```

## Getting Help

### Documentation and resources
- Official Kubernetes docs: https://kubernetes.io/docs/
- minikube docs: https://minikube.sigs.k8s.io/docs/
- kubectl cheat sheet: https://kubernetes.io/docs/reference/kubectl/cheatsheet/

### Community support
- Kubernetes Slack: https://slack.k8s.io/
- Stack Overflow: kubernetes tag
- GitHub issues for specific projects

### Diagnostic information for support
When asking for help, provide:
```bash
kubectl version
minikube version
minikube status
kubectl get nodes
kubectl get pods --all-namespaces
kubectl describe pod <problematic-pod>
kubectl get events
```