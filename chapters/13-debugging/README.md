# Chapter 13: Debugging and Troubleshooting

## Learning Objectives

By the end of this chapter, you will understand:
- Systematic approaches to Kubernetes troubleshooting
- Essential debugging tools and commands
- How to diagnose common application and infrastructure problems
- Log analysis and event interpretation
- Performance debugging techniques
- Network troubleshooting in Kubernetes

## The Art of Kubernetes Debugging

Kubernetes debugging requires a methodical approach because issues can occur at multiple layers:

1. **Application Layer**: Code bugs, configuration errors
2. **Container Layer**: Image issues, resource constraints
3. **Pod Layer**: Scheduling problems, health check failures
4. **Service Layer**: Network connectivity, DNS resolution
5. **Node Layer**: Resource exhaustion, kubelet issues
6. **Cluster Layer**: Control plane problems, networking issues

## Debugging Methodology

### The DEBUG Approach

**D**iscovery - Understand what's happening
**E**vents - Check cluster events for clues
**B**asic - Start with basic kubectl commands
**U**nderstand - Analyze logs and state
**G**o deeper - Use advanced debugging tools

### Systematic Troubleshooting Steps

1. **Define the problem** - What exactly is failing?
2. **Gather information** - Collect logs, events, and state
3. **Form hypotheses** - What could be causing this?
4. **Test hypotheses** - Verify your assumptions
5. **Implement solution** - Fix the root cause
6. **Verify fix** - Ensure the problem is resolved

## Essential Debugging Commands

### Quick Status Overview

```bash
# Cluster health check
kubectl get componentstatuses
kubectl get nodes
kubectl cluster-info

# Overall resource status
kubectl get all --all-namespaces
kubectl top nodes
kubectl top pods --all-namespaces
```

### Pod Debugging

```bash
# Basic pod information
kubectl get pods -o wide
kubectl describe pod <pod-name>

# Pod logs
kubectl logs <pod-name>
kubectl logs <pod-name> --previous
kubectl logs <pod-name> -c <container-name>
kubectl logs -f <pod-name>

# Execute commands in pod
kubectl exec -it <pod-name> -- /bin/bash
kubectl exec <pod-name> -- ps aux
kubectl exec <pod-name> -- netstat -tulpn
```

### Event Analysis

```bash
# Recent events
kubectl get events --sort-by=.metadata.creationTimestamp

# Events for specific object
kubectl describe pod <pod-name>
kubectl describe node <node-name>

# Events with timestamps
kubectl get events --sort-by=.metadata.creationTimestamp -o wide
```

## Common Problems and Solutions

### 1. Pod Stuck in Pending State

**Symptoms**: Pod remains in Pending status

**Debugging Steps**:

```bash
# Check pod details
kubectl describe pod <pod-name>

# Common issues to look for:
# - Insufficient resources
# - Node selector constraints
# - Pod affinity/anti-affinity rules
# - Persistent volume issues
```

**Example Investigation**:

```bash
# Check node resources
kubectl describe nodes

# Check resource quotas
kubectl describe resourcequota -n <namespace>

# Check persistent volumes
kubectl get pv
kubectl describe pvc <pvc-name>
```

**Solutions**:
- Increase cluster resources
- Adjust resource requests
- Fix node selector issues
- Resolve storage problems

### 2. Pod in CrashLoopBackOff

**Symptoms**: Pod keeps restarting

**Debugging Steps**:

```bash
# Check restart count
kubectl get pods

# View current logs
kubectl logs <pod-name>

# View previous container logs
kubectl logs <pod-name> --previous

# Check liveness probe configuration
kubectl describe pod <pod-name>
```

**Example Debug Session**:

Create `crashloop-debug.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: crashloop-app
spec:
  containers:
  - name: app
    image: nginx:1.21
    command: ["sh", "-c", "echo 'Starting app...'; sleep 5; exit 1"]
    livenessProbe:
      exec:
        command: ["echo", "healthy"]
      initialDelaySeconds: 10
      periodSeconds: 5
```

```bash
# Deploy problematic pod
kubectl apply -f crashloop-debug.yaml

# Watch the crash loop
kubectl get pods -w

# Debug the issue
kubectl logs crashloop-app
kubectl describe pod crashloop-app

# Fix by updating the command
kubectl patch pod crashloop-app -p '{"spec":{"containers":[{"name":"app","command":["nginx","-g","daemon off;"]}]}}'
```

### 3. Service Not Accessible

**Symptoms**: Cannot reach service endpoints

**Debugging Steps**:

```bash
# Check service configuration
kubectl get services
kubectl describe service <service-name>

# Check endpoints
kubectl get endpoints <service-name>

# Check pod labels
kubectl get pods --show-labels
```

**Network Debug Tools**:

Create `network-debug-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: network-debug
spec:
  containers:
  - name: debug
    image: nicolaka/netshoot
    command: ["sleep", "3600"]
```

```bash
# Deploy debug pod
kubectl apply -f network-debug-pod.yaml

# Test network connectivity
kubectl exec -it network-debug -- /bin/bash

# Inside the debug pod:
# nslookup <service-name>
# curl <service-name>:<port>
# ping <pod-ip>
# traceroute <service-ip>
```

### 4. Image Pull Errors

**Symptoms**: ErrImagePull or ImagePullBackOff

**Debugging Steps**:

```bash
# Check image name and tag
kubectl describe pod <pod-name>

# Test image pull manually
docker pull <image-name>

# Check image pull secrets
kubectl get secrets
kubectl describe secret <secret-name>
```

**Example Fix**:

```bash
# Create image pull secret
kubectl create secret docker-registry my-registry \
  --docker-server=<server> \
  --docker-username=<username> \
  --docker-password=<password>

# Add to pod spec
kubectl patch deployment <deployment-name> \
  -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"my-registry"}]}}}}'
```

### 5. DNS Resolution Issues

**Symptoms**: Services cannot find each other

**Debugging Steps**:

```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS resolution
kubectl run dns-test --image=busybox:1.28 -it --rm --restart=Never -- nslookup kubernetes.default

# Check DNS configuration
kubectl exec dns-test -- cat /etc/resolv.conf
```

**DNS Debug Script**:

Create `dns-debug.sh`:

```bash
#!/bin/bash

echo "=== DNS Troubleshooting ==="

# Check CoreDNS status
echo "CoreDNS pods:"
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Create test pod
kubectl run dns-debug --image=busybox:1.28 -it --rm --restart=Never -- sh -c "
echo 'Testing DNS resolution...'
nslookup kubernetes.default
nslookup kubernetes.default.svc.cluster.local
echo 'DNS config:'
cat /etc/resolv.conf
"
```

## Advanced Debugging Techniques

### 1. Resource Analysis

Create `resource-debug.sh`:

```bash
#!/bin/bash

echo "=== Resource Analysis ==="

# Node resources
echo "Node resource usage:"
kubectl top nodes

echo -e "\nNode details:"
kubectl describe nodes | grep -A 5 "Allocated resources"

# Pod resources
echo -e "\nTop resource consumers:"
kubectl top pods --all-namespaces --sort-by=memory
kubectl top pods --all-namespaces --sort-by=cpu

# Resource quotas
echo -e "\nResource quotas:"
kubectl get resourcequota --all-namespaces
```

### 2. Performance Debugging

Create `performance-debug.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: performance-test
spec:
  containers:
  - name: app
    image: nginx:1.21
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
  - name: monitoring
    image: prom/node-exporter
    ports:
    - containerPort: 9100
```

```bash
# Deploy performance test pod
kubectl apply -f performance-debug.yaml

# Monitor resource usage
kubectl top pod performance-test --containers

# Check detailed metrics
kubectl exec performance-test -c monitoring -- curl localhost:9100/metrics
```

### 3. Network Traffic Analysis

Create `network-policy-debug.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: debug-policy
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from: []
  egress:
  - to: []
```

```bash
# Test network policies
kubectl apply -f network-policy-debug.yaml

# Check connectivity before and after
kubectl exec network-debug -- curl <service-name>

# Remove policy
kubectl delete networkpolicy debug-policy
```

## Debugging Tools and Utilities

### 1. kubectl-debug Plugin

```bash
# Install kubectl-debug
curl -Lo kubectl-debug https://github.com/aylei/kubectl-debug/releases/download/v0.1.1/kubectl-debug_0.1.1_linux_amd64
chmod +x kubectl-debug
sudo mv kubectl-debug /usr/local/bin/

# Debug a running pod
kubectl debug <pod-name> --image=nicolaka/netshoot
```

### 2. Stern for Log Aggregation

```bash
# Install stern
brew install stern  # macOS
# or
curl -Lo stern https://github.com/wercker/stern/releases/download/1.21.0/stern_1.21.0_linux_amd64
chmod +x stern
sudo mv stern /usr/local/bin/

# Watch logs from multiple pods
stern <pod-prefix>
stern --selector app=myapp
```

### 3. Custom Debug Container

Create `debug-toolkit.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: debug-toolkit
spec:
  containers:
  - name: toolkit
    image: ubuntu:20.04
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        add: [ "NET_ADMIN", "SYS_PTRACE" ]
    volumeMounts:
    - name: proc
      mountPath: /host/proc
      readOnly: true
    - name: sys
      mountPath: /host/sys
      readOnly: true
  volumes:
  - name: proc
    hostPath:
      path: /proc
  - name: sys
    hostPath:
      path: /sys
  hostNetwork: true
  hostPID: true
```

```bash
# Deploy debug toolkit
kubectl apply -f debug-toolkit.yaml

# Install debugging tools
kubectl exec -it debug-toolkit -- bash
# apt update && apt install -y curl wget tcpdump netstat-nat dnsutils
```

## Application-Specific Debugging

### 1. Database Connection Issues

Create `db-debug.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mysql-debug
spec:
  containers:
  - name: mysql-client
    image: mysql:8.0
    command: ["sleep", "3600"]
    env:
    - name: MYSQL_HOST
      value: "mysql-service"
    - name: MYSQL_USER
      value: "root"
    - name: MYSQL_PASSWORD
      value: "password"
```

```bash
# Test database connectivity
kubectl exec -it mysql-debug -- mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW DATABASES;"

# Check connection parameters
kubectl exec mysql-debug -- nc -zv mysql-service 3306
```

### 2. Web Application Debugging

Create `webapp-debug.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-debug
spec:
  containers:
  - name: debug
    image: curlimages/curl
    command: ["sleep", "3600"]
```

```bash
# Test web application endpoints
kubectl exec -it webapp-debug -- curl -v http://webapp-service/health
kubectl exec webapp-debug -- curl -I http://webapp-service/api/users

# Check response times
kubectl exec webapp-debug -- curl -w "@curl-format.txt" -o /dev/null -s http://webapp-service/
```

Create `curl-format.txt`:

```
     time_namelookup:  %{time_namelookup}s\n
        time_connect:  %{time_connect}s\n
     time_appconnect:  %{time_appconnect}s\n
    time_pretransfer:  %{time_pretransfer}s\n
       time_redirect:  %{time_redirect}s\n
  time_starttransfer:  %{time_starttransfer}s\n
                     ----------\n
          time_total:  %{time_total}s\n
```

## Debugging Workflows

### 1. Pod Debugging Workflow

Create `debug-pod.sh`:

```bash
#!/bin/bash

POD_NAME=$1
NAMESPACE=${2:-default}

if [ -z "$POD_NAME" ]; then
    echo "Usage: $0 <pod-name> [namespace]"
    exit 1
fi

echo "=== Debugging Pod: $POD_NAME ==="

echo "1. Basic Information:"
kubectl get pod $POD_NAME -n $NAMESPACE -o wide

echo -e "\n2. Pod Description:"
kubectl describe pod $POD_NAME -n $NAMESPACE

echo -e "\n3. Pod Events:"
kubectl get events --field-selector involvedObject.name=$POD_NAME -n $NAMESPACE

echo -e "\n4. Pod Logs:"
kubectl logs $POD_NAME -n $NAMESPACE --tail=50

echo -e "\n5. Previous Logs (if restarted):"
kubectl logs $POD_NAME -n $NAMESPACE --previous --tail=50 2>/dev/null || echo "No previous logs"

echo -e "\n6. Resource Usage:"
kubectl top pod $POD_NAME -n $NAMESPACE 2>/dev/null || echo "Metrics not available"

echo -e "\n7. Security Context:"
kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.securityContext}'

echo -e "\n8. Environment Variables:"
kubectl exec $POD_NAME -n $NAMESPACE -- env 2>/dev/null || echo "Cannot access pod"
```

### 2. Service Debugging Workflow

Create `debug-service.sh`:

```bash
#!/bin/bash

SERVICE_NAME=$1
NAMESPACE=${2:-default}

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <service-name> [namespace]"
    exit 1
fi

echo "=== Debugging Service: $SERVICE_NAME ==="

echo "1. Service Details:"
kubectl get service $SERVICE_NAME -n $NAMESPACE -o wide

echo -e "\n2. Service Description:"
kubectl describe service $SERVICE_NAME -n $NAMESPACE

echo -e "\n3. Endpoints:"
kubectl get endpoints $SERVICE_NAME -n $NAMESPACE

echo -e "\n4. Pods matching selector:"
SELECTOR=$(kubectl get service $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.selector}' | tr -d '{}' | tr ',' ' ')
if [ ! -z "$SELECTOR" ]; then
    kubectl get pods -n $NAMESPACE -l "$SELECTOR"
else
    echo "No selector found"
fi

echo -e "\n5. Test connectivity:"
kubectl run test-$SERVICE_NAME --image=curlimages/curl --rm -i --restart=Never -- curl -m 5 $SERVICE_NAME.$NAMESPACE.svc.cluster.local 2>/dev/null || echo "Connection failed"
```

## Monitoring and Alerting for Debug

### 1. Event Monitoring

Create `event-monitor.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: event-monitor
spec:
  containers:
  - name: monitor
    image: busybox
    command:
    - /bin/sh
    - -c
    - |
      while true; do
        echo "=== Events at $(date) ==="
        kubectl get events --sort-by=.metadata.creationTimestamp | tail -10
        sleep 30
      done
```

### 2. Health Check Dashboard

Create `health-dashboard.sh`:

```bash
#!/bin/bash

while true; do
    clear
    echo "=== Kubernetes Health Dashboard ==="
    echo "Time: $(date)"
    echo

    echo "Node Status:"
    kubectl get nodes

    echo -e "\nPod Status:"
    kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

    echo -e "\nFailed Events (last 10):"
    kubectl get events --all-namespaces --field-selector type=Warning --sort-by=.metadata.creationTimestamp | tail -10

    sleep 30
done
```

## Performance Debugging

### 1. CPU and Memory Analysis

Create `resource-hog-detector.sh`:

```bash
#!/bin/bash

echo "=== Resource Hog Detection ==="

echo "Top CPU consumers:"
kubectl top pods --all-namespaces --sort-by=cpu | head -10

echo -e "\nTop Memory consumers:"  
kubectl top pods --all-namespaces --sort-by=memory | head -10

echo -e "\nPods with resource limits:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[0].resources.limits.cpu}{"\t"}{.spec.containers[0].resources.limits.memory}{"\n"}{end}' | column -t

echo -e "\nNodes under pressure:"
kubectl describe nodes | grep -A 5 "Conditions:" | grep -E "(MemoryPressure|DiskPressure|PIDPressure)"
```

### 2. Network Performance

Create `network-perf-test.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: network-perf-server
spec:
  containers:
  - name: server
    image: networkstatic/iperf3
    command: ["iperf3", "-s"]
    ports:
    - containerPort: 5201

---
apiVersion: v1
kind: Service
metadata:
  name: network-perf-service
spec:
  selector:
    app: network-perf-server
  ports:
  - port: 5201
    targetPort: 5201

---
apiVersion: v1
kind: Pod  
metadata:
  name: network-perf-client
spec:
  containers:
  - name: client
    image: networkstatic/iperf3
    command: ["sleep", "3600"]
```

```bash
# Run network performance test
kubectl exec network-perf-client -- iperf3 -c network-perf-service -t 30
```

## Troubleshooting Checklist

### Pre-Debugging Checklist

- [ ] Understand the expected behavior
- [ ] Identify what changed recently
- [ ] Check if the issue is widespread or isolated
- [ ] Gather error messages and symptoms
- [ ] Note the timeline of when issues started

### During Debugging

- [ ] Start with basic kubectl commands
- [ ] Check events and logs
- [ ] Verify configurations
- [ ] Test connectivity
- [ ] Check resource usage
- [ ] Validate security settings

### Post-Debugging

- [ ] Document the root cause
- [ ] Implement monitoring to prevent recurrence
- [ ] Update runbooks and documentation
- [ ] Consider infrastructure improvements
- [ ] Share learnings with the team

## Best Practices

### 1. Logging Best Practices

```yaml
# Structured logging in applications
apiVersion: v1
kind: ConfigMap
metadata:
  name: logging-config
data:
  log-config.json: |
    {
      "level": "info",
      "format": "json",
      "timestamp": true,
      "fields": {
        "service": "my-app",
        "version": "1.0.0"
      }
    }
```

### 2. Debug Labels and Annotations

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: debuggable-app
  labels:
    app: myapp
    version: v1.0.0
    environment: production
  annotations:
    debug.kubernetes.io/enabled: "true"
    debug.kubernetes.io/maintainer: "team@example.com"
    debug.kubernetes.io/last-debugged: "2023-10-01"
spec:
  # pod spec
```

### 3. Resource Limits for Debugging

```yaml
# Debug container with appropriate resources
spec:
  containers:
  - name: debug
    image: nicolaka/netshoot
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
```

## Key Takeaways

1. **Systematic approach** - Follow a methodical debugging process
2. **Start simple** - Begin with basic kubectl commands
3. **Check events** - Events often contain crucial debugging information
4. **Use the right tools** - Different problems require different tools
5. **Document findings** - Keep track of what you discover
6. **Prevention** - Set up monitoring to catch issues early
7. **Practice** - Regular debugging practice improves skills

## Hands-On Exercises

### Exercise 1: Debug a Failing Pod

1. Deploy a pod with intentional misconfigurations
2. Use systematic debugging to identify issues
3. Fix the problems step by step

### Exercise 2: Network Troubleshooting

1. Create a service that's not accessible
2. Use network debugging tools to diagnose
3. Implement the fix and verify connectivity

### Exercise 3: Performance Investigation

1. Deploy an application with resource issues
2. Use monitoring tools to identify bottlenecks
3. Optimize resource allocation

## Cleaning Up

```bash
# Remove debug pods
kubectl delete pod network-debug dns-debug debug-toolkit mysql-debug webapp-debug

# Remove test deployments
kubectl delete pod performance-test crashloop-app event-monitor

# Remove debug services
kubectl delete service network-perf-service
```

## Commands Reference

| Command | Purpose |
|---------|---------|
| `kubectl describe <resource> <name>` | Detailed resource information |
| `kubectl logs <pod> --previous` | Previous container logs |
| `kubectl exec -it <pod> -- <command>` | Execute in container |
| `kubectl get events --sort-by=.metadata.creationTimestamp` | Recent events |
| `kubectl top pods/nodes` | Resource usage |
| `kubectl port-forward <pod> <local>:<remote>` | Port forwarding |
| `kubectl debug <pod> --image=<debug-image>` | Debug running pod |

---

**Next Chapter**: [Security Best Practices](../14-security/) - Learn essential security practices and hardening techniques for Kubernetes.