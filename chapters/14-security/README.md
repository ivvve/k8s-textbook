# Chapter 14: Security Best Practices

## Learning Objectives

By the end of this chapter, you will understand:
- Kubernetes security fundamentals and threat model
- Role-Based Access Control (RBAC) implementation
- Pod security standards and contexts
- Network security and policies
- Secret management and encryption
- Image security and scanning
- Security monitoring and auditing

## Kubernetes Security Overview

Kubernetes security operates on the principle of **defense in depth** with multiple layers:

### Security Layers

1. **Infrastructure Security**: Secure the underlying nodes and network
2. **Cluster Security**: Secure the Kubernetes control plane
3. **Authentication & Authorization**: Control who can access what
4. **Pod Security**: Secure the workloads running in pods
5. **Network Security**: Control traffic between pods and services
6. **Secret Management**: Protect sensitive data
7. **Image Security**: Ensure container images are secure
8. **Monitoring & Auditing**: Detect and respond to threats

### Threat Model

Common Kubernetes security threats:
- **Malicious containers**: Compromised or malicious container images
- **Privilege escalation**: Containers gaining excessive permissions
- **Lateral movement**: Attackers moving between pods/nodes
- **Data exfiltration**: Unauthorized access to sensitive data
- **Denial of service**: Resource exhaustion attacks
- **Supply chain attacks**: Compromised dependencies or images

## Authentication and Authorization

### Authentication Methods

Kubernetes supports multiple authentication methods:

1. **X.509 Client Certificates**
2. **Bearer Tokens**
3. **Authentication Proxy**
4. **HTTP Basic Auth** (deprecated)
5. **OpenID Connect (OIDC)**

### Service Accounts

Create `service-account-demo.yaml`:

```yaml
# Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: webapp-service-account
  namespace: default
automountServiceAccountToken: false  # Security best practice

---
# Pod using the service account
apiVersion: v1
kind: Pod
metadata:
  name: webapp-pod
spec:
  serviceAccountName: webapp-service-account
  containers:
  - name: webapp
    image: nginx:1.21
    volumeMounts:
    - name: service-account-token
      mountPath: /var/run/secrets/tokens
      readOnly: true
  volumes:
  - name: service-account-token
    projected:
      sources:
      - serviceAccountToken:
          path: token
          expirationSeconds: 3600
```

```bash
# Create service account
kubectl apply -f service-account-demo.yaml

# Check service account token
kubectl describe serviceaccount webapp-service-account
```

## Role-Based Access Control (RBAC)

RBAC controls who can perform what actions on which resources.

### RBAC Components

1. **Role/ClusterRole**: Defines permissions
2. **RoleBinding/ClusterRoleBinding**: Assigns roles to subjects
3. **Subjects**: Users, groups, or service accounts

### Creating Roles and RoleBindings

Create `rbac-demo.yaml`:

```yaml
# Namespace for demo
apiVersion: v1
kind: Namespace
metadata:
  name: rbac-demo

---
# Role for pod management
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: rbac-demo
  name: pod-manager
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]

---
# Role for read-only access
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: rbac-demo
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]

---
# Service Account for application
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-service-account
  namespace: rbac-demo

---
# RoleBinding for pod management
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-manager-binding
  namespace: rbac-demo
subjects:
- kind: ServiceAccount
  name: app-service-account
  namespace: rbac-demo
roleRef:
  kind: Role
  name: pod-manager
  apiGroup: rbac.authorization.k8s.io

---
# ClusterRole for node information
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list"]

---
# ClusterRoleBinding for node access
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: node-reader-binding
subjects:
- kind: ServiceAccount
  name: app-service-account
  namespace: rbac-demo
roleRef:
  kind: ClusterRole
  name: node-reader
  apiGroup: rbac.authorization.k8s.io
```

```bash
# Apply RBAC configuration
kubectl apply -f rbac-demo.yaml

# Test permissions
kubectl auth can-i get pods --as=system:serviceaccount:rbac-demo:app-service-account -n rbac-demo
kubectl auth can-i delete nodes --as=system:serviceaccount:rbac-demo:app-service-account
```

### Built-in ClusterRoles

```bash
# List built-in cluster roles
kubectl get clusterroles | grep "system:"

# View cluster-admin role (full access)
kubectl describe clusterrole cluster-admin

# View view role (read-only access)
kubectl describe clusterrole view

# View edit role (modify resources)
kubectl describe clusterrole edit
```

### RBAC Best Practices

Create `rbac-best-practices.yaml`:

```yaml
# Principle of least privilege
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: webapp-role
rules:
# Only allow specific actions on specific resources
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["webapp-config"]  # Restrict to specific configmap
  verbs: ["get"]
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["webapp-secret"]  # Restrict to specific secret
  verbs: ["get"]
# No wildcard permissions
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list"]  # No create/update/delete

---
# Separate service account per application
apiVersion: v1
kind: ServiceAccount
metadata:
  name: webapp-production-sa
  namespace: production
automountServiceAccountToken: false

---
# Time-limited binding (use external tools for this)
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: webapp-binding
  namespace: production
  annotations:
    rbac.authorization.kubernetes.io/expires: "2024-12-31T23:59:59Z"
subjects:
- kind: ServiceAccount
  name: webapp-production-sa
  namespace: production
roleRef:
  kind: Role
  name: webapp-role
  apiGroup: rbac.authorization.k8s.io
```

## Pod Security

### Pod Security Standards

Kubernetes defines three pod security levels:

1. **Privileged**: Unrestricted policy (least secure)
2. **Baseline**: Minimally restrictive policy
3. **Restricted**: Heavily restricted policy (most secure)

### Pod Security Context

Create `pod-security-demo.yaml`:

```yaml
# Insecure pod (privileged)
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
spec:
  containers:
  - name: app
    image: nginx:1.21
    securityContext:
      privileged: true  # BAD: Full access to host
      runAsUser: 0      # BAD: Running as root

---
# Secure pod
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    # Pod-level security context
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.21
    securityContext:
      # Container-level security context
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 1000
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE  # Only add necessary capabilities
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: var-cache
      mountPath: /var/cache/nginx
    - name: var-run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: var-cache
    emptyDir: {}
  - name: var-run
    emptyDir: {}
```

### Pod Security Standards Enforcement

Create `pod-security-policy.yaml`:

```yaml
# Namespace with pod security enforcement
apiVersion: v1
kind: Namespace
metadata:
  name: secure-namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted

---
# Deployment that meets restricted standards
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: secure-namespace
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534  # nobody user
        runAsGroup: 65534
        fsGroup: 65534
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: gcr.io/distroless/static-debian11
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 65534
          capabilities:
            drop:
            - ALL
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
```

## Network Security

### Network Policies

Network policies control traffic flow between pods.

Create `network-policy-demo.yaml`:

```yaml
# Namespace for network policy demo
apiVersion: v1
kind: Namespace
metadata:
  name: netpol-demo

---
# Frontend deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: netpol-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
      tier: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:1.21
        ports:
        - containerPort: 80

---
# Backend deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: netpol-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
      tier: backend
  template:
    metadata:
      labels:
        app: backend
        tier: backend
    spec:
      containers:
      - name: backend
        image: nginx:1.21
        ports:
        - containerPort: 80

---
# Database deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: netpol-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
      tier: database
  template:
    metadata:
      labels:
        app: database
        tier: database
    spec:
      containers:
      - name: database
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "password"
        ports:
        - containerPort: 3306

---
# Services
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: netpol-demo
spec:
  selector:
    app: frontend
  ports:
  - port: 80

---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: netpol-demo
spec:
  selector:
    app: backend
  ports:
  - port: 80

---
apiVersion: v1
kind: Service
metadata:
  name: database-service
  namespace: netpol-demo
spec:
  selector:
    app: database
  ports:
  - port: 3306

---
# Network Policy: Deny all ingress traffic by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: netpol-demo
spec:
  podSelector: {}
  policyTypes:
  - Ingress

---
# Network Policy: Allow frontend to backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: netpol-demo
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 80

---
# Network Policy: Allow backend to database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: netpol-demo
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 3306

---
# Network Policy: Allow external access to frontend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-to-frontend
  namespace: netpol-demo
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Ingress
  ingress:
  - ports:
    - protocol: TCP
      port: 80
```

```bash
# Deploy network policy demo
kubectl apply -f network-policy-demo.yaml

# Test connectivity (should work: frontend -> backend -> database)
kubectl exec -n netpol-demo deployment/frontend -- curl backend-service

# Test blocked connectivity (should fail: direct access to database from frontend)
kubectl exec -n netpol-demo deployment/frontend -- curl database-service:3306
```

### Advanced Network Policies

Create `advanced-network-policies.yaml`:

```yaml
# Egress policy for external API access
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-api
  namespace: netpol-demo
spec:
  podSelector:
    matchLabels:
      needs-external-api: "true"
  policyTypes:
  - Egress
  egress:
  # Allow DNS resolution
  - to: []
    ports:
    - protocol: UDP
      port: 53
  # Allow HTTPS to external APIs
  - to: []
    ports:
    - protocol: TCP
      port: 443
  # Block everything else

---
# Namespace-based policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-monitoring
  namespace: netpol-demo
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080  # Metrics port

---
# Time-based policy (using external controllers)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: business-hours-only
  namespace: netpol-demo
  annotations:
    policy.kubernetes.io/schedule: "0 9-17 * * 1-5"  # 9 AM to 5 PM, Mon-Fri
spec:
  podSelector:
    matchLabels:
      access-level: business-hours
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
```

## Secret Management

### Creating and Using Secrets

Create `secret-management-demo.yaml`:

```yaml
# Generic secret
apiVersion: v1
kind: Secret
metadata:
  name: app-credentials
  namespace: default
type: Opaque
stringData:
  username: "admin"
  password: "super-secret-password"
  api-key: "abc123xyz789"

---
# TLS secret
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
  namespace: default
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi... # base64 encoded certificate
  tls.key: LS0tLS1CRUdJTi... # base64 encoded private key

---
# Docker registry secret
apiVersion: v1
kind: Secret
metadata:
  name: registry-secret
  namespace: default
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: eyJhdXRocyI6... # base64 encoded docker config

---
# Pod using secrets securely
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    image: nginx:1.21
    env:
    # Use secret as environment variable (less secure)
    - name: API_KEY
      valueFrom:
        secretKeyRef:
          name: app-credentials
          key: api-key
    volumeMounts:
    # Mount secret as file (more secure)
    - name: credentials
      mountPath: /etc/credentials
      readOnly: true
    - name: tls
      mountPath: /etc/tls
      readOnly: true
  volumes:
  - name: credentials
    secret:
      secretName: app-credentials
      defaultMode: 0400  # Read-only for owner
  - name: tls
    secret:
      secretName: tls-secret
      defaultMode: 0400
  imagePullSecrets:
  - name: registry-secret
```

### External Secret Management

Create `external-secrets-demo.yaml`:

```yaml
# Using External Secrets Operator (example)
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: default
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "demo-role"

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: vault-secret
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-secret
    creationPolicy: Owner
  data:
  - secretKey: password
    remoteRef:
      key: myapp
      property: password
  - secretKey: token
    remoteRef:
      key: myapp  
      property: token
```

## Image Security

### Secure Base Images

Create `secure-dockerfile`:

```dockerfile
# Use minimal base images
FROM gcr.io/distroless/java:11

# Or use scratch for static binaries
# FROM scratch

# Avoid using latest tags
# FROM ubuntu:latest  # BAD
FROM ubuntu:20.04   # GOOD

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy application
COPY --chown=appuser:appuser app.jar /app/

# Switch to non-root user
USER appuser

# Set security context
LABEL security.context="restricted"

# Use read-only filesystem
VOLUME ["/tmp"]

WORKDIR /app
EXPOSE 8080

CMD ["java", "-jar", "app.jar"]
```

### Image Scanning

Create `image-security-scan.yaml`:

```yaml
# Pod with security scanning
apiVersion: v1
kind: Pod
metadata:
  name: scanned-app
  annotations:
    trivy.security/scan: "true"
    trivy.security/policy: "restricted"
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
  containers:
  - name: app
    image: gcr.io/distroless/static-debian11:latest
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
    resources:
      limits:
        memory: "128Mi"
        cpu: "500m"
      requests:
        memory: "64Mi" 
        cpu: "250m"
```

### Image Policy Enforcement

Create `image-policy.yaml`:

```yaml
# OPA Gatekeeper policy for image security
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredsecuritycontext
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredSecurityContext
      validation:
        properties:
          runAsNonRoot:
            type: boolean
          readOnlyRootFilesystem:
            type: boolean
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredsecuritycontext
        
        violation[{"msg": msg}] {
            container := input.review.object.spec.containers[_]
            not container.securityContext.runAsNonRoot
            msg := "Container must run as non-root user"
        }
        
        violation[{"msg": msg}] {
            container := input.review.object.spec.containers[_]
            not container.securityContext.readOnlyRootFilesystem
            msg := "Container must use read-only root filesystem"
        }

---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredSecurityContext
metadata:
  name: must-have-security-context
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
  parameters:
    runAsNonRoot: true
    readOnlyRootFilesystem: true
```

## Security Monitoring and Auditing

### Audit Logging

Create `audit-policy.yaml`:

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Log security-sensitive events at Metadata level
- level: Metadata
  namespaces: ["kube-system", "kube-public"]
  verbs: ["create", "update", "patch", "delete"]
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
  - group: "rbac.authorization.k8s.io"
    resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]

# Log authentication failures
- level: Metadata
  omitStages:
    - RequestReceived
  resources:
  - group: ""
    resources: ["pods"]
  verbs: ["create"]

# Log pod exec/attach commands
- level: Request
  verbs: ["create"]
  resources:
  - group: ""
    resources: ["pods/exec", "pods/attach", "pods/portforward"]

# Don't log low-level reads
- level: None
  verbs: ["get", "list", "watch"]
  resources:
  - group: ""
    resources: ["pods", "services", "endpoints"]
```

### Security Monitoring Dashboard

Create `security-monitor.sh`:

```bash
#!/bin/bash

echo "=== Kubernetes Security Monitoring ==="
echo "Timestamp: $(date)"
echo

# Check for privileged pods
echo "Privileged Pods:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[?(@.spec.securityContext.privileged==true)]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}'

echo -e "\nPods running as root:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[?(@.spec.securityContext.runAsUser==0)]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}'

echo -e "\nPods with host network:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[?(@.spec.hostNetwork==true)]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}'

echo -e "\nPods with host PID:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[?(@.spec.hostPID==true)]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}'

echo -e "\nPods with excessive capabilities:"
kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[]?.securityContext?.capabilities?.add[]? == "SYS_ADMIN" or .spec.containers[]?.securityContext?.capabilities?.add[]? == "NET_ADMIN") | "\(.metadata.namespace)\t\(.metadata.name)"'

echo -e "\nServices with external IPs:"
kubectl get services --all-namespaces -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.loadBalancer.ingress[0].ip}{"\n"}{end}'

echo -e "\nRecent security events:"
kubectl get events --all-namespaces --field-selector type=Warning | grep -i -E "(failed|error|security|denied|forbidden)" | tail -10
```

### Runtime Security Monitoring

Create `runtime-security.yaml`:

```yaml
# Falco DaemonSet for runtime security
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: falco
  namespace: falco-system
spec:
  selector:
    matchLabels:
      app: falco
  template:
    metadata:
      labels:
        app: falco
    spec:
      serviceAccount: falco
      hostNetwork: true
      hostPID: true
      containers:
      - name: falco
        image: falcosecurity/falco:latest
        securityContext:
          privileged: true
        volumeMounts:
        - name: dev
          mountPath: /host/dev
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: boot
          mountPath: /host/boot
          readOnly: true
        - name: lib-modules
          mountPath: /host/lib/modules
          readOnly: true
        - name: usr
          mountPath: /host/usr
          readOnly: true
        - name: etc
          mountPath: /host/etc
          readOnly: true
      volumes:
      - name: dev
        hostPath:
          path: /dev
      - name: proc
        hostPath:
          path: /proc
      - name: boot
        hostPath:
          path: /boot
      - name: lib-modules
        hostPath:
          path: /lib/modules
      - name: usr
        hostPath:
          path: /usr
      - name: etc
        hostPath:
          path: /etc
```

## Security Hardening Checklist

### Cluster Level Security

Create `cluster-hardening.yaml`:

```yaml
# API Server hardening
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-apiserver-config
  namespace: kube-system
data:
  config.yaml: |
    # Disable insecure port
    insecure-port: 0
    
    # Enable audit logging
    audit-log-path: /var/log/audit.log
    audit-policy-file: /etc/kubernetes/audit-policy.yaml
    
    # Enable admission controllers
    enable-admission-plugins: NodeRestriction,PodSecurityPolicy,ResourceQuota
    
    # Disable profiling
    profiling: false
    
    # Enable RBAC
    authorization-mode: Node,RBAC
    
    # Secure service account settings
    service-account-lookup: true
    service-account-key-file: /etc/kubernetes/pki/sa.key

---
# Kubelet hardening
apiVersion: v1
kind: ConfigMap
metadata:
  name: kubelet-config
  namespace: kube-system
data:
  config.yaml: |
    # Disable anonymous auth
    anonymous-auth: false
    
    # Enable webhook authorization
    authorization-mode: Webhook
    
    # Disable read-only port
    read-only-port: 0
    
    # Enable TLS
    tls-cert-file: /etc/kubernetes/pki/kubelet.crt
    tls-private-key-file: /etc/kubernetes/pki/kubelet.key
    
    # Protect kernel defaults
    protect-kernel-defaults: true
```

### Node Security

Create `node-security.sh`:

```bash
#!/bin/bash

echo "=== Node Security Hardening ==="

# Disable unnecessary services
systemctl disable cups
systemctl disable avahi-daemon
systemctl disable bluetooth

# Configure firewall
ufw enable
ufw default deny incoming
ufw allow ssh
ufw allow 6443/tcp  # Kubernetes API
ufw allow 10250/tcp # Kubelet API
ufw allow 30000:32767/tcp # NodePort range

# Kernel hardening
cat >> /etc/sysctl.conf << EOF
# Network security
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1

# Disable IPv6 if not needed
net.ipv6.conf.all.disable_ipv6 = 1

# Security settings
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
EOF

sysctl -p

# File system security
chmod 600 /etc/kubernetes/admin.conf
chmod 600 /etc/kubernetes/kubelet.conf
chown root:root /etc/kubernetes/manifests/*
chmod 644 /etc/kubernetes/manifests/*

echo "Node hardening completed"
```

## Compliance and Governance

### CIS Kubernetes Benchmark

Create `cis-benchmark-check.sh`:

```bash
#!/bin/bash

echo "=== CIS Kubernetes Benchmark Check ==="

# 1.1.1 Ensure that the API server pod specification file permissions are set to 644 or more restrictive
echo "Checking API server manifest permissions:"
stat -c %a /etc/kubernetes/manifests/kube-apiserver.yaml

# 1.1.2 Ensure that the API server pod specification file ownership is set to root:root
echo "Checking API server manifest ownership:"
stat -c %U:%G /etc/kubernetes/manifests/kube-apiserver.yaml

# 1.2.6 Ensure that the --insecure-port argument is set to 0
echo "Checking API server insecure port:"
ps -ef | grep kube-apiserver | grep -E -- --insecure-port=0

# 1.2.8 Ensure that the --profiling argument is set to false
echo "Checking API server profiling:"
ps -ef | grep kube-apiserver | grep -E -- --profiling=false

# 1.3.2 Ensure that the --profiling argument is set to false (Controller Manager)
echo "Checking Controller Manager profiling:"
ps -ef | grep kube-controller-manager | grep -E -- --profiling=false

# 4.1.1 Ensure that the kubelet service file permissions are set to 644 or more restrictive
echo "Checking kubelet service file permissions:"
stat -c %a /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

echo "CIS benchmark check completed"
```

### Policy as Code

Create `policy-as-code.yaml`:

```yaml
# Open Policy Agent (OPA) Gatekeeper
apiVersion: config.gatekeeper.sh/v1alpha1
kind: Config
metadata:
  name: config
  namespace: gatekeeper-system
spec:
  match:
    - excludedNamespaces: ["kube-system", "kube-public", "gatekeeper-system"]
  validation:
    traces:
      - user: "admin"
        kind: "Pod"
  readiness:
    statsEnabled: true

---
# Security policy: Require security context
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8ssecuritycontext
spec:
  crd:
    spec:
      names:
        kind: K8sSecurityContext
      validation:
        properties:
          requiredSecurityContext:
            type: object
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8ssecuritycontext
        
        violation[{"msg": msg}] {
            container := input.review.object.spec.containers[_]
            not container.securityContext.runAsNonRoot
            msg := "Container must specify runAsNonRoot: true"
        }

---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sSecurityContext
metadata:
  name: security-context-required
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
  parameters:
    requiredSecurityContext:
      runAsNonRoot: true
      readOnlyRootFilesystem: true
```

## Incident Response

### Security Incident Playbook

Create `incident-response.sh`:

```bash
#!/bin/bash

INCIDENT_TYPE=$1

case $INCIDENT_TYPE in
  "compromised-pod")
    echo "=== Compromised Pod Response ==="
    echo "1. Isolate the pod"
    # kubectl label pod $POD_NAME quarantine=true
    # kubectl patch networkpolicy deny-all --type merge -p '{"spec":{"podSelector":{"matchLabels":{"quarantine":"true"}}}}'
    
    echo "2. Collect evidence"
    # kubectl logs $POD_NAME > evidence-logs.txt
    # kubectl describe pod $POD_NAME > evidence-describe.txt
    
    echo "3. Remove the pod"
    # kubectl delete pod $POD_NAME
    ;;
    
  "privilege-escalation")
    echo "=== Privilege Escalation Response ==="
    echo "1. Identify affected resources"
    kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.securityContext.privileged==true)'
    
    echo "2. Check RBAC assignments"
    kubectl get clusterrolebindings -o json | jq '.items[] | select(.roleRef.name=="cluster-admin")'
    
    echo "3. Audit recent changes"
    kubectl get events --sort-by=.metadata.creationTimestamp | grep -E "(rolebinding|clusterrolebinding)"
    ;;
    
  "data-breach")
    echo "=== Data Breach Response ==="
    echo "1. Identify exposed secrets"
    kubectl get secrets --all-namespaces
    
    echo "2. Rotate compromised credentials"
    # kubectl delete secret compromised-secret
    # kubectl create secret generic new-secret --from-literal=...
    
    echo "3. Update affected workloads"
    # kubectl rollout restart deployment/affected-app
    ;;
    
  *)
    echo "Usage: $0 {compromised-pod|privilege-escalation|data-breach}"
    exit 1
    ;;
esac
```

## Security Testing

### Penetration Testing

Create `security-testing.yaml`:

```yaml
# Kube-hunter for security testing
apiVersion: batch/v1
kind: Job
metadata:
  name: kube-hunter
spec:
  template:
    spec:
      containers:
      - name: kube-hunter
        image: aquasec/kube-hunter:latest
        command: ["kube-hunter"]
        args: ["--pod"]
      restartPolicy: Never
  backoffLimit: 4

---
# Kube-bench for CIS benchmark testing
apiVersion: batch/v1
kind: Job
metadata:
  name: kube-bench
spec:
  template:
    spec:
      hostPID: true
      containers:
      - name: kube-bench
        image: aquasec/kube-bench:latest
        command: ["kube-bench", "--json"]
        volumeMounts:
        - name: var-lib-etcd
          mountPath: /var/lib/etcd
          readOnly: true
        - name: var-lib-kubelet
          mountPath: /var/lib/kubelet
          readOnly: true
        - name: etc-kubernetes
          mountPath: /etc/kubernetes
          readOnly: true
      volumes:
      - name: var-lib-etcd
        hostPath:
          path: "/var/lib/etcd"
      - name: var-lib-kubelet
        hostPath:
          path: "/var/lib/kubelet"
      - name: etc-kubernetes
        hostPath:
          path: "/etc/kubernetes"
      restartPolicy: Never
```

## Best Practices Summary

### Security Checklist

- [ ] **Authentication & Authorization**
  - [ ] Disable anonymous access
  - [ ] Use RBAC with least privilege
  - [ ] Rotate certificates regularly
  - [ ] Use service accounts per application

- [ ] **Pod Security**
  - [ ] Run containers as non-root
  - [ ] Use read-only root filesystems
  - [ ] Drop all capabilities, add only necessary ones
  - [ ] Set resource limits
  - [ ] Use security contexts

- [ ] **Network Security**
  - [ ] Implement network policies
  - [ ] Use TLS for all communications
  - [ ] Isolate sensitive workloads
  - [ ] Monitor network traffic

- [ ] **Secret Management**
  - [ ] Use Kubernetes secrets (not environment variables)
  - [ ] Encrypt secrets at rest
  - [ ] Rotate secrets regularly
  - [ ] Use external secret management systems

- [ ] **Image Security**
  - [ ] Use minimal base images
  - [ ] Scan images for vulnerabilities
  - [ ] Sign images
  - [ ] Use private registries
  - [ ] Keep images updated

- [ ] **Monitoring & Auditing**
  - [ ] Enable audit logging
  - [ ] Monitor for security events
  - [ ] Set up alerting
  - [ ] Regular security assessments

## Key Takeaways

1. **Defense in depth** - Security must be implemented at every layer
2. **Principle of least privilege** - Grant minimum necessary permissions
3. **Zero trust architecture** - Verify everything, trust nothing
4. **Continuous monitoring** - Security is an ongoing process
5. **Automation** - Use policies and tools to enforce security
6. **Regular updates** - Keep all components updated and patched
7. **Incident preparedness** - Have response plans ready

## Hands-On Exercises

### Exercise 1: RBAC Implementation

1. Create a namespace for a development team
2. Set up appropriate roles and role bindings
3. Test access controls with different service accounts

### Exercise 2: Network Policy Design

1. Deploy a multi-tier application
2. Implement network policies for traffic isolation
3. Test and verify the policies work correctly

### Exercise 3: Security Scanning

1. Deploy an application with security vulnerabilities
2. Use scanning tools to identify issues
3. Fix the vulnerabilities and re-scan

## Cleaning Up

```bash
# Delete security demo resources
kubectl delete namespace rbac-demo netpol-demo secure-namespace

# Remove security monitoring pods
kubectl delete pod secure-pod insecure-pod secure-app

# Clean up security jobs
kubectl delete job kube-hunter kube-bench

# Remove network policies
kubectl delete networkpolicy --all --all-namespaces
```

## Commands Reference

| Command | Purpose |
|---------|---------|
| `kubectl auth can-i <verb> <resource>` | Check permissions |
| `kubectl create role <name> --verb=<verbs> --resource=<resources>` | Create role |
| `kubectl create rolebinding <name> --role=<role> --user=<user>` | Create role binding |
| `kubectl get pods -o jsonpath='{.spec.securityContext}'` | Check security context |
| `kubectl apply -f network-policy.yaml` | Apply network policy |
| `kubectl get networkpolicies` | List network policies |
| `kubectl create secret generic <name> --from-literal=<key>=<value>` | Create secret |

---

**Next Chapter**: [Production Readiness](../15-production/) - Learn how to prepare Kubernetes deployments for production environments.