# Chapter 12: Best Practices and Production

## Learning Objectives

By the end of this chapter, you will be able to:
- Implement production-ready Kustomize project organization patterns
- Apply security best practices for production deployments
- Optimize performance and resource management
- Set up monitoring and observability for Kustomized applications
- Plan and execute migration strategies from other tools
- Establish governance and compliance frameworks

## Production-Ready Project Organization

### Scalable Directory Structure

```
enterprise-app/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── deployment/
│   │   ├── api-server.yaml
│   │   ├── worker.yaml
│   │   └── scheduler.yaml
│   ├── services/
│   │   ├── api-service.yaml
│   │   └── internal-services.yaml
│   ├── configs/
│   │   ├── app-config.yaml
│   │   └── logging-config.yaml
│   └── rbac/
│       ├── service-accounts.yaml
│       ├── roles.yaml
│       └── role-bindings.yaml
├── components/
│   ├── monitoring/
│   │   ├── kustomization.yaml
│   │   ├── prometheus.yaml
│   │   ├── grafana.yaml
│   │   └── alertmanager.yaml
│   ├── security/
│   │   ├── kustomization.yaml
│   │   ├── network-policies.yaml
│   │   ├── pod-security-policies.yaml
│   │   └── security-contexts.yaml
│   ├── database/
│   │   ├── kustomization.yaml
│   │   ├── postgres.yaml
│   │   ├── redis.yaml
│   │   └── migrations.yaml
│   └── ingress/
│       ├── kustomization.yaml
│       ├── ingress-controller.yaml
│       ├── certificates.yaml
│       └── ingress-rules.yaml
├── overlays/
│   ├── development/
│   │   ├── kustomization.yaml
│   │   ├── patches/
│   │   │   ├── resource-limits.yaml
│   │   │   ├── replicas.yaml
│   │   │   └── debug-config.yaml
│   │   └── secrets/
│   │       └── dev-secrets.yaml
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   ├── patches/
│   │   │   ├── resource-limits.yaml
│   │   │   ├── replicas.yaml
│   │   │   └── monitoring.yaml
│   │   └── secrets/
│   │       └── staging-secrets.yaml
│   └── production/
│       ├── kustomization.yaml
│       ├── patches/
│       │   ├── high-availability.yaml
│       │   ├── security-hardening.yaml
│       │   ├── performance-tuning.yaml
│       │   └── monitoring-full.yaml
│       └── secrets/
│           ├── prod-secrets.yaml
│           └── certificates.yaml
├── tests/
│   ├── integration/
│   │   ├── kustomization.yaml
│   │   └── test-suite.yaml
│   └── e2e/
│       ├── kustomization.yaml
│       └── end-to-end-tests.yaml
└── docs/
    ├── architecture.md
    ├── deployment-guide.md
    └── troubleshooting.md
```

### Base Configuration Best Practices

**1. Resource Separation**:
```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: enterprise-app-base

# Separate resources by type for better organization
resources:
  - namespace.yaml
  - deployment/
  - services/
  - configs/
  - rbac/

# Common configurations
commonLabels:
  app.kubernetes.io/name: enterprise-app
  app.kubernetes.io/managed-by: kustomize

commonAnnotations:
  app.kubernetes.io/version: "2.1.0"
  documentation: "https://docs.company.com/enterprise-app"

# Resource naming
namePrefix: ""
nameSuffix: ""
```

**2. Modular Resource Files**:
```yaml
# base/deployment/api-server.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  labels:
    component: api-server
    tier: backend
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      component: api-server
  template:
    metadata:
      labels:
        component: api-server
        tier: backend
    spec:
      serviceAccountName: api-server
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: api-server
        image: company/api-server:2.1.0
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        - containerPort: 9090
          name: metrics
          protocol: TCP
        env:
        - name: PORT
          value: "8080"
        - name: METRICS_PORT
          value: "9090"
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: config
          mountPath: /app/config
          readOnly: true
        - name: secrets
          mountPath: /app/secrets
          readOnly: true
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/cache
      volumes:
      - name: config
        configMap:
          name: api-config
      - name: secrets
        secret:
          secretName: api-secrets
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir:
          sizeLimit: 1Gi
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: component
                  operator: In
                  values:
                  - api-server
              topologyKey: kubernetes.io/hostname
```

## Security Best Practices

### Comprehensive Security Framework

**1. Security Component**:
```yaml
# components/security/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: security-baseline

resources:
  - network-policies.yaml
  - pod-security-standards.yaml
  - service-accounts.yaml
  - rbac.yaml

patches:
  - path: security-contexts.yaml
    target:
      kind: Deployment
```

**2. Network Policies**:
```yaml
# components/security/network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-server-netpol
spec:
  podSelector:
    matchLabels:
      component: api-server
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          component: ingress-controller
    - namespaceSelector:
        matchLabels:
          name: ingress-system
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          component: database
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - podSelector:
        matchLabels:
          component: redis
    ports:
    - protocol: TCP
      port: 6379
  - to: []  # Allow DNS
    ports:
    - protocol: UDP
      port: 53

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**3. Pod Security Standards**:
```yaml
# components/security/pod-security-standards.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: enterprise-app
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted

---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-server-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      component: api-server

---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: worker-pdb
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      component: worker
```

**4. RBAC Configuration**:
```yaml
# components/security/rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-server
  labels:
    component: api-server

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: api-server-role
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: api-server-binding
subjects:
- kind: ServiceAccount
  name: api-server
  namespace: enterprise-app
roleRef:
  kind: Role
  name: api-server-role
  apiGroup: rbac.authorization.k8s.io
```

### Secret Management Best Practices

**1. External Secret Management**:
```yaml
# components/security/external-secrets.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-secret-store
spec:
  provider:
    vault:
      server: "https://vault.company.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "enterprise-app"

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: api-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-secret-store
    kind: SecretStore
  target:
    name: api-secrets
    creationPolicy: Owner
  data:
  - secretKey: database-password
    remoteRef:
      key: enterprise-app/database
      property: password
  - secretKey: jwt-secret
    remoteRef:
      key: enterprise-app/auth
      property: jwt-secret
  - secretKey: api-key
    remoteRef:
      key: enterprise-app/external
      property: api-key
```

**2. Sealed Secrets Integration**:
```yaml
# overlays/production/sealed-secrets.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: api-secrets
spec:
  encryptedData:
    database-password: AgBy3i4OJSWK+PiTySYZZA9rO435Q...
    jwt-secret: AgARABIQ4VsS6Q+6qnrI8JvPKQJz...
    api-key: AgCBQF5SJFQKEQKnYYqJ8R2SLdL...
  template:
    metadata:
      name: api-secrets
      labels:
        app: enterprise-app
```

## Performance Optimization

### Resource Management

**1. Horizontal Pod Autoscaler**:
```yaml
# components/scaling/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-server-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-server
  minReplicas: 3
  maxReplicas: 100
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
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "100"
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 25
        periodSeconds: 60
      - type: Pods
        value: 2
        periodSeconds: 60
      selectPolicy: Min
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
      - type: Pods
        value: 5
        periodSeconds: 30
      selectPolicy: Max
```

**2. Vertical Pod Autoscaler**:
```yaml
# components/scaling/vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: api-server-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-server
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: api-server
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 2000m
        memory: 2Gi
      controlledResources: ["cpu", "memory"]
```

**3. Node Affinity and Taints**:
```yaml
# overlays/production/node-scheduling.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node.kubernetes.io/instance-type
                operator: In
                values:
                - m5.large
                - m5.xlarge
                - m5.2xlarge
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values:
                - us-west-2a
                - us-west-2b
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: component
                operator: In
                values:
                - api-server
            topologyKey: kubernetes.io/hostname
      tolerations:
      - key: "dedicated"
        operator: "Equal"
        value: "enterprise-app"
        effect: "NoSchedule"
```

## Monitoring and Observability

### Comprehensive Monitoring Stack

**1. Prometheus Configuration**:
```yaml
# components/monitoring/prometheus.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
spec:
  replicas: 2
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:v2.40.0
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: data
          mountPath: /prometheus
        command:
        - /bin/prometheus
        - --config.file=/etc/prometheus/prometheus.yml
        - --storage.tsdb.path=/prometheus
        - --web.console.libraries=/etc/prometheus/console_libraries
        - --web.console.templates=/etc/prometheus/consoles
        - --web.enable-lifecycle
        - --web.enable-admin-api
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: data
        persistentVolumeClaim:
          claimName: prometheus-data

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 30s
      evaluation_interval: 30s
    
    rule_files:
      - "alert_rules.yml"
    
    alerting:
      alertmanagers:
      - static_configs:
        - targets:
          - alertmanager:9093
    
    scrape_configs:
    - job_name: 'kubernetes-apiservers'
      kubernetes_sd_configs:
      - role: endpoints
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: default;kubernetes;https
    
    - job_name: 'enterprise-app'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__

  alert_rules.yml: |
    groups:
    - name: enterprise-app-alerts
      rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} for {{ $labels.instance }}"
      
      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High memory usage"
          description: "Memory usage is {{ $value | humanizePercentage }} for {{ $labels.pod }}"
```

**2. Grafana Dashboards**:
```yaml
# components/monitoring/grafana.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
data:
  enterprise-app-dashboard.json: |
    {
      "dashboard": {
        "title": "Enterprise App Dashboard",
        "panels": [
          {
            "title": "Request Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(http_requests_total[5m])",
                "legendFormat": "{{ instance }} - {{ method }}"
              }
            ]
          },
          {
            "title": "Error Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(http_requests_total{status=~\"5..\"}[5m])",
                "legendFormat": "{{ instance }} - 5xx errors"
              }
            ]
          },
          {
            "title": "Response Time",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
                "legendFormat": "95th percentile"
              }
            ]
          }
        ]
      }
    }
```

**3. Logging Configuration**:
```yaml
# components/monitoring/logging.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         5
        Log_Level     info
        Daemon        off
        Parsers_File  parsers.conf
    
    [INPUT]
        Name              tail
        Path              /var/log/containers/*.log
        Parser            docker
        Tag               kube.*
        Refresh_Interval  5
        Mem_Buf_Limit     50MB
        Skip_Long_Lines   On
    
    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Merge_Log           On
        K8S-Logging.Parser  On
        K8S-Logging.Exclude Off
    
    [OUTPUT]
        Name  es
        Match *
        Host  elasticsearch.logging.svc.cluster.local
        Port  9200
        Index enterprise-app-logs
        Type  _doc

  parsers.conf: |
    [PARSER]
        Name   docker
        Format json
        Time_Key time
        Time_Format %Y-%m-%dT%H:%M:%S.%L
        Time_Keep On
```

## Migration Strategies

### From Helm to Kustomize

**1. Analysis Phase**:
```bash
# Analyze existing Helm chart
helm template my-app ./helm-chart --values values.yaml > helm-output.yaml

# Identify components
grep -E "^kind:" helm-output.yaml | sort | uniq -c

# Extract base resources
mkdir -p kustomize-migration/{base,overlays}
```

**2. Migration Steps**:
```yaml
# Step 1: Create base resources from Helm templates
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml  # Extracted from Helm template
  - service.yaml     # Extracted from Helm template
  - configmap.yaml   # Extracted from Helm template

# Replace Helm templating with Kustomize generators
configMapGenerator:
  - name: app-config
    literals:
      - LOG_LEVEL=info  # Was {{ .Values.logLevel }}
      - PORT=8080       # Was {{ .Values.service.port }}
```

**3. Validation Process**:
```bash
# Validate migration
kustomize build base > kustomize-output.yaml
diff helm-output.yaml kustomize-output.yaml

# Test deployment
kubectl apply --dry-run=client -f kustomize-output.yaml
```

### From Plain YAML

**1. Consolidation Strategy**:
```yaml
# Identify and group existing YAML files
manifests/
├── app-deployment.yaml
├── app-service.yaml
├── app-configmap.yaml
├── worker-deployment.yaml
├── worker-service.yaml
└── database-deployment.yaml

# Create Kustomize structure
base/
├── kustomization.yaml
├── app/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── worker/
│   ├── deployment.yaml
│   └── service.yaml
└── database/
    └── deployment.yaml
```

**2. Refactoring Process**:
```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - app/
  - worker/
  - database/

# Apply consistent labeling
commonLabels:
  app.kubernetes.io/name: enterprise-app
  app.kubernetes.io/managed-by: kustomize

# Standardize naming
namePrefix: ""
```

## Governance and Compliance

### Policy as Code

**1. Open Policy Agent Integration**:
```yaml
# policies/security-policy.rego
package kubernetes.admission

deny[msg] {
    input.request.kind.kind == "Deployment"
    input.request.object.spec.template.spec.securityContext.runAsRoot == true
    msg := "Containers must not run as root"
}

deny[msg] {
    input.request.kind.kind == "Deployment"
    not input.request.object.spec.template.spec.securityContext.readOnlyRootFilesystem == true
    msg := "Containers must use read-only root filesystem"
}

deny[msg] {
    input.request.kind.kind == "Service"
    input.request.object.spec.type == "NodePort"
    not input.request.object.metadata.namespace == "development"
    msg := "NodePort services only allowed in development namespace"
}
```

**2. Resource Quotas and Limits**:
```yaml
# governance/resource-quotas.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: enterprise-app-quota
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    limits.cpu: "200"
    limits.memory: 400Gi
    pods: "100"
    persistentvolumeclaims: "20"
    services: "20"
    secrets: "50"
    configmaps: "50"

---
apiVersion: v1
kind: LimitRange
metadata:
  name: enterprise-app-limits
spec:
  limits:
  - default:
      cpu: "1000m"
      memory: "1Gi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    type: Container
  - max:
      cpu: "4000m"
      memory: "8Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
    type: Container
```

### Compliance Framework

**1. SOC 2 Compliance**:
```yaml
# compliance/soc2/audit-logging.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  namespaces: ["enterprise-app"]
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
  - group: "apps"
    resources: ["deployments", "replicasets"]

- level: RequestResponse
  namespaces: ["enterprise-app"]
  resources:
  - group: ""
    resources: ["pods/exec", "pods/portforward"]
```

**2. PCI DSS Compliance**:
```yaml
# compliance/pci-dss/network-segmentation.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: pci-network-isolation
spec:
  podSelector:
    matchLabels:
      pci-scope: "true"
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          pci-scope: "true"
  egress:
  - to:
    - podSelector:
        matchLabels:
          pci-scope: "true"
```

## Testing and Validation

### Automated Testing Pipeline

**1. Kustomize Validation**:
```bash
#!/bin/bash
# scripts/validate-kustomize.sh

set -e

echo "Validating Kustomize configurations..."

# Test all overlays build successfully
for overlay in overlays/*; do
    if [ -d "$overlay" ]; then
        echo "Testing $overlay..."
        kustomize build "$overlay" > /dev/null
        echo "✓ $overlay builds successfully"
    fi
done

# Validate against Kubernetes API
for overlay in overlays/*; do
    if [ -d "$overlay" ]; then
        echo "Validating $overlay against Kubernetes API..."
        kustomize build "$overlay" | kubectl apply --dry-run=server -f -
        echo "✓ $overlay passes Kubernetes validation"
    fi
done

# Check for common issues
echo "Checking for common issues..."
if kustomize build overlays/production | grep -q "image.*latest"; then
    echo "⚠ Warning: Production uses 'latest' image tags"
fi

echo "All validations passed!"
```

**2. Security Scanning**:
```bash
#!/bin/bash
# scripts/security-scan.sh

# Run Polaris security scan
polaris audit --audit-path overlays/production --format json > polaris-report.json

# Run Falco rules validation
for overlay in overlays/*; do
    echo "Scanning $overlay with Falco rules..."
    kustomize build "$overlay" | falco -r /etc/falco/k8s_audit_rules.yaml
done

# Check for secrets in plain text
if grep -r "password\|secret\|key" overlays/ --include="*.yaml" | grep -v "secretGenerator"; then
    echo "❌ Potential secrets found in plain text"
    exit 1
fi
```

### Integration Testing

**1. Test Environment Setup**:
```yaml
# tests/integration/test-environment.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../overlays/development

components:
  - test-data

namePrefix: test-
namespace: integration-tests

configMapGenerator:
  - name: test-config
    literals:
      - TEST_MODE=true
      - DATABASE_URL=postgresql://test-db:5432/testdb
```

**2. Health Check Tests**:
```bash
#!/bin/bash
# scripts/integration-tests.sh

NAMESPACE="integration-tests"
TIMEOUT=300

echo "Deploying test environment..."
kubectl apply -k tests/integration/

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=enterprise-app -n $NAMESPACE --timeout=${TIMEOUT}s

echo "Running health checks..."
kubectl port-forward -n $NAMESPACE service/test-api-server 8080:80 &
PF_PID=$!

sleep 5

# Test health endpoints
curl -f http://localhost:8080/health/live || exit 1
curl -f http://localhost:8080/health/ready || exit 1

# Test API endpoints
curl -f http://localhost:8080/api/v1/status || exit 1

kill $PF_PID

echo "Cleaning up test environment..."
kubectl delete -k tests/integration/

echo "✓ Integration tests passed!"
```

## Documentation Standards

### Architecture Documentation

**1. System Overview**:
```markdown
# Enterprise App Architecture

## Overview
The Enterprise App is deployed using Kustomize with a multi-environment strategy supporting development, staging, and production deployments.

## Components
- **API Server**: Main application server handling HTTP requests
- **Worker**: Background job processing
- **Database**: PostgreSQL primary data store
- **Cache**: Redis caching layer
- **Monitoring**: Prometheus, Grafana, and Alertmanager stack

## Directory Structure
```
enterprise-app/
├── base/           # Base configurations
├── components/     # Reusable components
├── overlays/       # Environment-specific customizations
└── tests/          # Testing configurations
```

## Deployment Workflow
1. Changes merged to main branch
2. CI pipeline validates Kustomize configurations
3. Automated deployment to development environment
4. Manual promotion to staging after testing
5. Manual promotion to production after validation
```

**2. Runbook Documentation**:
```markdown
# Enterprise App Runbook

## Deployment Procedures

### Development Deployment
```bash
kubectl apply -k overlays/development/
```

### Production Deployment
```bash
# Validate configuration
kustomize build overlays/production/ | kubectl apply --dry-run=server -f -

# Deploy with approval
kubectl apply -k overlays/production/

# Verify deployment
kubectl rollout status deployment/api-server -n enterprise-app
```

## Troubleshooting

### Common Issues

**Pod Stuck in Pending State**
- Check resource quotas: `kubectl describe quota -n enterprise-app`
- Check node capacity: `kubectl describe nodes`
- Check PVC status: `kubectl get pvc -n enterprise-app`

**High Memory Usage**
- Check metrics: Access Grafana dashboard
- Scale horizontally: `kubectl scale deployment api-server --replicas=10`
- Investigate memory leaks: `kubectl exec -it <pod> -- /bin/sh`
```

## Chapter Summary

This chapter provided comprehensive production best practices:

### Key Areas Covered
- **Project Organization**: Scalable directory structures and modular resource organization
- **Security Framework**: Comprehensive security practices including network policies, RBAC, and secret management
- **Performance Optimization**: Resource management, autoscaling, and node scheduling strategies
- **Monitoring and Observability**: Complete monitoring stack with Prometheus, Grafana, and logging
- **Migration Strategies**: Structured approaches for migrating from Helm and plain YAML
- **Governance and Compliance**: Policy as code, resource quotas, and compliance frameworks
- **Testing and Validation**: Automated testing pipelines and security scanning
- **Documentation Standards**: Architecture documentation and operational runbooks

### Production Readiness Checklist

✅ **Security**
- Network policies implemented
- RBAC configured
- Secrets managed externally
- Security contexts enforced
- Pod security standards applied

✅ **Reliability**
- Health checks configured
- Resource limits set
- Pod disruption budgets defined
- Horizontal and vertical autoscaling enabled
- Anti-affinity rules applied

✅ **Observability**
- Metrics collection enabled
- Logging centralized
- Alerting configured
- Dashboards created
- Tracing implemented

✅ **Operations**
- Documentation complete
- Runbooks available
- Testing automated
- Deployment pipelines established
- Rollback procedures defined

This comprehensive approach ensures your Kustomize-based applications are production-ready, secure, scalable, and maintainable.

---

**Previous**: [Chapter 11: CI/CD Integration](11-cicd-integration.md)

**Quick Links**: [Table of Contents](../README.md) | [Appendices](../appendices/) | [Examples](../examples/chapter-12/)