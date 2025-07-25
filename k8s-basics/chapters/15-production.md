# Chapter 15: Production Readiness

## Learning Objectives

By the end of this chapter, you will understand:
- What it means to be production-ready in Kubernetes
- High availability and disaster recovery strategies
- Performance optimization and resource management
- Monitoring, logging, and observability at scale
- Backup and upgrade strategies
- Migration from development to production environments
- Next steps in your Kubernetes journey

## Production Readiness Checklist

### Infrastructure Readiness

- [ ] **Multi-node cluster** with redundancy
- [ ] **Separate control plane nodes** (HA control plane)
- [ ] **Persistent storage** with backups
- [ ] **Network redundancy** and load balancing
- [ ] **Security hardening** implemented
- [ ] **Monitoring and alerting** in place
- [ ] **Backup and disaster recovery** plan
- [ ] **Documentation** and runbooks

### Application Readiness

- [ ] **Health checks** properly configured
- [ ] **Resource limits** and requests set
- [ ] **Graceful shutdown** handling
- [ ] **Configuration externalized**
- [ ] **Secrets properly managed**
- [ ] **Logging structured** and centralized
- [ ] **Metrics exposed** for monitoring
- [ ] **Security policies** applied

## High Availability Architecture

### Control Plane HA

Create `ha-control-plane.yaml`:

```yaml
# HA Control Plane Configuration (for reference)
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.28.0
controlPlaneEndpoint: "k8s-api.example.com:6443"
etcd:
  external:
    endpoints:
    - https://etcd1.example.com:2379
    - https://etcd2.example.com:2379
    - https://etcd3.example.com:2379
    caFile: /etc/kubernetes/pki/etcd/ca.crt
    certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
    keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key
networking:
  serviceSubnet: "10.96.0.0/12"
  podSubnet: "10.244.0.0/16"
apiServer:
  certSANs:
  - "k8s-api.example.com"
  - "10.0.0.10"
  - "10.0.0.11" 
  - "10.0.0.12"
  extraArgs:
    audit-log-maxage: "30"
    audit-log-maxbackup: "10"
    audit-log-maxsize: "100"
    audit-log-path: /var/log/audit.log
```

### Application HA Patterns

Create `ha-application.yaml`:

```yaml
# HA Web Application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-ha
  labels:
    app: webapp
    tier: frontend
spec:
  replicas: 5  # Multiple replicas for HA
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        tier: frontend
    spec:
      # Anti-affinity to spread pods across nodes
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - webapp
              topologyKey: kubernetes.io/hostname
      containers:
      - name: webapp
        image: nginx:1.21
        ports:
        - containerPort: 80
        # Comprehensive health checks
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
        # Graceful shutdown
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 15"]
        # Resource management
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        # Security context
        securityContext:
          runAsNonRoot: true
          runAsUser: 65534
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
        # Volume mounts for writable directories
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
      # Termination grace period
      terminationGracePeriodSeconds: 30

---
# Service with session affinity for stateful apps
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  labels:
    app: webapp
spec:
  type: ClusterIP
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
    name: http
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 300

---
# HPA for automatic scaling
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp-ha
  minReplicas: 3
  maxReplicas: 20
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
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60

---
# PDB for disruption protection
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: webapp-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: webapp
```

## Data Persistence and Backup

### Persistent Storage Strategy

Create `production-storage.yaml`:

```yaml
# Storage Class for production
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: kubernetes.io/aws-ebs  # Change for your cloud provider
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer

---
# StatefulSet for database
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-production
spec:
  serviceName: mysql-headless
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - mysql
            topologyKey: kubernetes.io/hostname
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: root-password
        - name: MYSQL_REPLICATION_USER
          value: replicator
        - name: MYSQL_REPLICATION_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: replication-password
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
        - name: config
          mountPath: /etc/mysql/conf.d
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
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
      volumes:
      - name: config
        configMap:
          name: mysql-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 100Gi

---
# Headless service for StatefulSet
apiVersion: v1
kind: Service
metadata:
  name: mysql-headless
spec:
  clusterIP: None
  selector:
    app: mysql
  ports:
  - port: 3306
    name: mysql
```

### Backup Strategy

Create `backup-strategy.yaml`:

```yaml
# Backup CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mysql-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: mysql-backup
            image: mysql:8.0
            command:
            - /bin/bash
            - -c
            - |
              BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
              BACKUP_FILE="backup_${BACKUP_DATE}.sql"
              
              echo "Starting backup at $(date)"
              mysqldump -h mysql-headless \
                -u root \
                -p${MYSQL_ROOT_PASSWORD} \
                --all-databases \
                --single-transaction \
                --routines \
                --triggers > /backup/${BACKUP_FILE}
              
              # Compress backup
              gzip /backup/${BACKUP_FILE}
              
              # Upload to cloud storage (example with AWS S3)
              aws s3 cp /backup/${BACKUP_FILE}.gz s3://my-backup-bucket/mysql/
              
              # Clean up local file
              rm /backup/${BACKUP_FILE}.gz
              
              echo "Backup completed at $(date)"
            env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: root-password
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: aws-credentials
                  key: access-key-id
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: aws-credentials
                  key: secret-access-key
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            emptyDir: {}
          restartPolicy: OnFailure

---
# Velero backup for cluster resources
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
spec:
  schedule: "0 1 * * *"  # Daily at 1 AM
  template:
    includedNamespaces:
    - production
    - staging
    excludedResources:
    - events
    - events.events.k8s.io
    storageLocation: default
    ttl: 720h0m0s  # 30 days
```

## Monitoring and Observability

### Comprehensive Monitoring Stack

Create `monitoring-stack.yaml`:

```yaml
# Prometheus ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 30s
      evaluation_interval: 30s
    
    rule_files:
    - "/etc/prometheus/rules/*.yml"
    
    alerting:
      alertmanagers:
      - static_configs:
        - targets:
          - alertmanager:9093
    
    scrape_configs:
    # Kubernetes API Server
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
    
    # Node Exporter
    - job_name: 'kubernetes-nodes'
      kubernetes_sd_configs:
      - role: node
      relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      - target_label: __address__
        replacement: kubernetes.default.svc:443
      - source_labels: [__meta_kubernetes_node_name]
        regex: (.+)
        target_label: __metrics_path__
        replacement: /api/v1/nodes/${1}/proxy/metrics
    
    # Pods
    - job_name: 'kubernetes-pods'
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
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name

---
# Alert Rules
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-rules
  namespace: monitoring
data:
  kubernetes.yml: |
    groups:
    - name: kubernetes.rules
      rules:
      # High CPU usage
      - alert: HighCPUUsage
        expr: (100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% for more than 5 minutes"
      
      # High memory usage
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 90% for more than 5 minutes"
      
      # Pod crash looping
      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Pod is crash looping"
          description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is crash looping"
      
      # Deployment replica mismatch
      - alert: DeploymentReplicasMismatch
        expr: kube_deployment_spec_replicas != kube_deployment_status_replicas_available
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Deployment replicas mismatch"
          description: "Deployment {{ $labels.deployment }} has {{ $labels.spec_replicas }} desired but {{ $labels.available_replicas }} available"

---
# Grafana Dashboard ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: kubernetes-dashboard
  namespace: monitoring
data:
  kubernetes-overview.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Kubernetes Overview",
        "tags": ["kubernetes"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "CPU Usage",
            "type": "graph",
            "targets": [
              {
                "expr": "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
                "legendFormat": "{{ instance }}"
              }
            ]
          },
          {
            "id": 2,
            "title": "Memory Usage",
            "type": "graph",
            "targets": [
              {
                "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
                "legendFormat": "{{ instance }}"
              }
            ]
          },
          {
            "id": 3,
            "title": "Pod Status",
            "type": "stat",
            "targets": [
              {
                "expr": "kube_pod_status_phase",
                "legendFormat": "{{ phase }}"
              }
            ]
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "30s"
      }
    }
```

### Application Metrics

Create `application-metrics.yaml`:

```yaml
# Application with metrics endpoint
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: metrics-app
  template:
    metadata:
      labels:
        app: metrics-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
          name: http
        - containerPort: 8080
          name: metrics
        # Sidecar for metrics
      - name: metrics-exporter
        image: nginx/nginx-prometheus-exporter:0.10.0
        args:
        - -nginx.scrape-uri=http://localhost/nginx_status
        ports:
        - containerPort: 9113
          name: metrics
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"

---
# ServiceMonitor for Prometheus Operator
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: metrics-app-monitor
spec:
  selector:
    matchLabels:
      app: metrics-app
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

## Logging Architecture

### Centralized Logging

Create `logging-stack.yaml`:

```yaml
# Fluentd DaemonSet for log collection
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: fluentd
  template:
    metadata:
      labels:
        name: fluentd
    spec:
      serviceAccount: fluentd
      containers:
      - name: fluentd
        image: fluent/fluentd-kubernetes-daemonset:v1.15-debian-elasticsearch7-1
        env:
        - name: FLUENT_ELASTICSEARCH_HOST
          value: "elasticsearch.logging.svc.cluster.local"
        - name: FLUENT_ELASTICSEARCH_PORT
          value: "9200"
        - name: FLUENT_ELASTICSEARCH_SCHEME
          value: "http"
        resources:
          limits:
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: config-volume
          mountPath: /fluentd/etc/fluent.conf
          subPath: fluent.conf
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: config-volume
        configMap:
          name: fluentd-config

---
# Fluentd Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
  namespace: kube-system
data:
  fluent.conf: |
    @include kubernetes.conf
    
    # Kubernetes logs
    <match kubernetes.**>
      @type elasticsearch
      @id out_es
      @log_level info
      include_tag_key true
      host "#{ENV['FLUENT_ELASTICSEARCH_HOST']}"
      port "#{ENV['FLUENT_ELASTICSEARCH_PORT']}"
      scheme "#{ENV['FLUENT_ELASTICSEARCH_SCHEME']}"
      ssl_verify false
      reload_connections false
      reconnect_on_error true
      reload_on_failure true
      log_es_400_reason false
      logstash_prefix kubernetes
      logstash_format true
      index_name kubernetes
      type_name _doc
      <buffer>
        @type file
        path /var/log/fluentd-buffers/kubernetes.system.buffer
        flush_mode interval
        retry_type exponential_backoff
        flush_thread_count 2
        flush_interval 5s
        retry_forever
        retry_max_interval 30
        chunk_limit_size 2M
        queue_limit_length 8
        overflow_action block
      </buffer>
    </match>
```

### Structured Logging Example

Create `structured-logging-app.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: structured-logging-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: structured-logging-app
  template:
    metadata:
      labels:
        app: structured-logging-app
    spec:
      containers:
      - name: app
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            echo "{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"info\",\"service\":\"my-app\",\"version\":\"1.0.0\",\"message\":\"Processing request\",\"request_id\":\"$(uuidgen)\",\"user_id\":\"user123\",\"duration_ms\":$((RANDOM % 1000))}"
            sleep 5
            if [ $((RANDOM % 10)) -eq 0 ]; then
              echo "{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"error\",\"service\":\"my-app\",\"version\":\"1.0.0\",\"message\":\"Database connection failed\",\"error\":\"connection timeout\",\"request_id\":\"$(uuidgen)\"}"
            fi
          done
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
```

## Performance Optimization

### Resource Management

Create `resource-optimization.yaml`:

```yaml
# ResourceQuota for namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
    persistentvolumeclaims: "10"
    services: "20"
    services.loadbalancers: "2"

---
# LimitRange for default limits
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limits
  namespace: production
spec:
  limits:
  - default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    max:
      cpu: "2"
      memory: "4Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
    type: Container

---
# VerticalPodAutoscaler for automatic right-sizing
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: webapp-vpa
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp-ha
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: webapp
      maxAllowed:
        cpu: "1"
        memory: "1Gi"
      minAllowed:
        cpu: "100m"
        memory: "128Mi"
```

### Node Optimization

Create `node-optimization.yaml`:

```yaml
# Node affinity for workload placement
apiVersion: apps/v1
kind: Deployment
metadata:
  name: compute-intensive-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: compute-intensive-app
  template:
    metadata:
      labels:
        app: compute-intensive-app
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-type
                operator: In
                values:
                - compute-optimized
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            preference:
              matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values:
                - amd64
      tolerations:
      - key: "high-performance"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
      containers:
      - name: app
        image: my-compute-app:latest
        resources:
          requests:
            cpu: "2"
            memory: "4Gi"
          limits:
            cpu: "4"
            memory: "8Gi"

---
# Priority Class for critical workloads
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000
globalDefault: false
description: "High priority class for critical applications"

---
# Deployment using priority class
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: critical-app
  template:
    metadata:
      labels:
        app: critical-app
    spec:
      priorityClassName: high-priority
      containers:
      - name: app
        image: critical-app:latest
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "1"
            memory: "2Gi"
```

## Disaster Recovery

### Backup and Restore Procedures

Create `disaster-recovery.yaml`:

```yaml
# Disaster Recovery Plan ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: dr-procedures
  namespace: operations
data:
  recovery-plan.md: |
    # Disaster Recovery Procedures
    
    ## RTO/RPO Targets
    - **RTO (Recovery Time Objective)**: 4 hours
    - **RPO (Recovery Point Objective)**: 1 hour
    
    ## Recovery Procedures
    
    ### 1. Assess Damage
    ```bash
    kubectl get nodes
    kubectl get pods --all-namespaces
    kubectl get pv
    ```
    
    ### 2. Restore etcd from backup
    ```bash
    ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-snapshot.db \
      --data-dir=/var/lib/etcd-restore \
      --name=master-1 \
      --initial-cluster=master-1=https://10.0.0.10:2380 \
      --initial-advertise-peer-urls=https://10.0.0.10:2380
    ```
    
    ### 3. Restore application data
    ```bash
    # Restore from Velero backup
    velero restore create --from-backup daily-backup-20231201
    
    # Restore database
    mysql -u root -p < /backup/mysql-backup-20231201.sql
    ```
    
    ### 4. Validate recovery
    ```bash
    # Check all pods are running
    kubectl get pods --all-namespaces
    
    # Run health checks
    curl -f http://webapp.example.com/health
    
    # Verify data integrity
    kubectl exec mysql-0 -- mysql -u root -p -e "SELECT COUNT(*) FROM users;"
    ```
  
  recovery-scripts.sh: |
    #!/bin/bash
    
    # Automated recovery script
    set -e
    
    echo "Starting disaster recovery..."
    
    # Check cluster state
    if ! kubectl cluster-info &> /dev/null; then
      echo "Cluster not accessible, initiating cluster recovery"
      # Cluster recovery procedures here
    fi
    
    # Restore from backup
    echo "Restoring applications from backup..."
    velero restore create disaster-recovery-$(date +%Y%m%d-%H%M%S) \
      --from-backup daily-backup-latest
    
    # Wait for restore to complete
    echo "Waiting for restore to complete..."
    kubectl wait --for=condition=Completed restore/disaster-recovery-* --timeout=1800s
    
    # Validate services
    echo "Validating services..."
    for service in webapp-service api-service database-service; do
      if kubectl get service $service &> /dev/null; then
        echo "✓ $service is available"
      else
        echo "✗ $service is missing"
      fi
    done
    
    echo "Disaster recovery completed"

---
# Velero backup schedule for DR
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: disaster-recovery-backup
  namespace: velero
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  template:
    includedNamespaces:
    - production
    - staging
    - monitoring
    excludedResources:
    - events
    - events.events.k8s.io
    - nodes
    - endpoints
    storageLocation: default
    volumeSnapshotLocations:
    - default
    ttl: 168h0m0s  # 7 days
    hooks:
      resources:
      - name: mysql-backup-hook
        includedNamespaces:
        - production
        labelSelector:
          matchLabels:
            app: mysql
        hooks:
        - exec:
            container: mysql
            command:
            - /bin/bash
            - -c
            - mysqldump --all-databases > /tmp/backup.sql
            onError: Fail
        - exec:
            container: mysql
            command:
            - /bin/bash
            - -c
            - rm /tmp/backup.sql
            onError: Continue
```

## Migration Strategies

### Blue-Green Deployment

Create `blue-green-deployment.sh`:

```bash
#!/bin/bash

# Blue-Green Deployment Script
set -e

NAMESPACE=${1:-production}
APP_NAME=${2:-webapp}
NEW_VERSION=${3:-v2.0.0}

echo "Starting blue-green deployment for $APP_NAME to version $NEW_VERSION"

# Deploy green environment
echo "Deploying green environment..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}-green
  namespace: ${NAMESPACE}
  labels:
    app: ${APP_NAME}
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ${APP_NAME}
      version: green
  template:
    metadata:
      labels:
        app: ${APP_NAME}
        version: green
    spec:
      containers:
      - name: ${APP_NAME}
        image: ${APP_NAME}:${NEW_VERSION}
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
EOF

# Wait for green deployment to be ready
echo "Waiting for green deployment to be ready..."
kubectl rollout status deployment/${APP_NAME}-green -n ${NAMESPACE} --timeout=300s

# Run health checks on green environment
echo "Running health checks on green environment..."
kubectl run health-check-${RANDOM} --image=curlimages/curl --rm -i --restart=Never -n ${NAMESPACE} -- \
  curl -f http://${APP_NAME}-green-service.${NAMESPACE}.svc.cluster.local/health

# Switch traffic to green
echo "Switching traffic to green environment..."
kubectl patch service ${APP_NAME}-service -n ${NAMESPACE} -p '{"spec":{"selector":{"version":"green"}}}'

# Wait and monitor
echo "Monitoring green environment for 5 minutes..."
sleep 300

# Health check after traffic switch
if kubectl run final-health-check-${RANDOM} --image=curlimages/curl --rm -i --restart=Never -n ${NAMESPACE} -- \
   curl -f http://${APP_NAME}-service.${NAMESPACE}.svc.cluster.local/health; then
  echo "Green environment is healthy, cleaning up blue environment..."
  kubectl delete deployment ${APP_NAME}-blue -n ${NAMESPACE} || true
  
  # Rename green to blue for next deployment
  kubectl patch deployment ${APP_NAME}-green -n ${NAMESPACE} --type='merge' -p='{"metadata":{"name":"${APP_NAME}-blue"}}'
  
  echo "Blue-green deployment completed successfully!"
else
  echo "Health check failed, rolling back to blue environment..."
  kubectl patch service ${APP_NAME}-service -n ${NAMESPACE} -p '{"spec":{"selector":{"version":"blue"}}}'
  kubectl delete deployment ${APP_NAME}-green -n ${NAMESPACE}
  exit 1
fi
```

### Canary Deployment

Create `canary-deployment.yaml`:

```yaml
# Canary deployment with Flagger
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: webapp-canary
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  progressDeadlineSeconds: 60
  service:
    port: 80
    targetPort: 80
    gateways:
    - webapp-gateway
    hosts:
    - webapp.example.com
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 1m
    webhooks:
    - name: load-test
      url: http://flagger-loadtester.test/
      metadata:
        type: bash
        cmd: "hey -z 10m -q 10 -c 2 http://webapp.example.com/"
```

## Cost Optimization

### Resource Right-Sizing

Create `cost-optimization.sh`:

```bash
#!/bin/bash

# Cost Optimization Analysis
echo "=== Kubernetes Cost Optimization Report ==="
echo "Generated: $(date)"
echo

# Resource requests vs usage analysis
echo "Resource Requests vs Usage Analysis:"
echo "======================================"

kubectl top pods --all-namespaces --containers | while read namespace pod container cpu memory; do
  if [[ $namespace != "NAMESPACE" ]]; then
    # Get resource requests
    requests=$(kubectl get pod $pod -n $namespace -o jsonpath='{.spec.containers[?(@.name=="'$container'")].resources.requests}')
    echo "Pod: $namespace/$pod Container: $container"
    echo "  Current Usage - CPU: $cpu, Memory: $memory"
    echo "  Requests: $requests"
    echo
  fi
done

# Unused resources
echo "Unused Resources:"
echo "================="

# Unused PVCs
echo "Unused PVCs:"
kubectl get pvc --all-namespaces -o json | jq -r '
  .items[] | 
  select(.status.phase == "Bound") |
  select((.metadata.annotations // {})["volume.beta.kubernetes.io/storage-provisioner"] != null) |
  "\(.metadata.namespace)/\(.metadata.name)"
' | while read pvc; do
  namespace=$(echo $pvc | cut -d'/' -f1)
  name=$(echo $pvc | cut -d'/' -f2)
  
  # Check if PVC is being used by any pod
  if ! kubectl get pods -n $namespace -o json | jq -e --arg pvc "$name" '
    .items[] | select(.spec.volumes[]?.persistentVolumeClaim?.claimName == $pvc)
  ' > /dev/null 2>&1; then
    echo "  Unused PVC: $pvc"
  fi
done

# Over-provisioned nodes
echo -e "\nNode Resource Utilization:"
kubectl top nodes | while read node cpu_percent cpu_usage memory_percent memory_usage; do
  if [[ $node != "NAME" ]]; then
    cpu_num=$(echo $cpu_percent | tr -d '%')
    memory_num=$(echo $memory_percent | tr -d '%')
    
    if [[ $cpu_num -lt 20 ]] && [[ $memory_num -lt 30 ]]; then
      echo "  Under-utilized node: $node (CPU: $cpu_percent, Memory: $memory_percent)"
    fi
  fi
done

# Recommendations
echo -e "\nCost Optimization Recommendations:"
echo "=================================="
echo "1. Consider using Cluster Autoscaler for dynamic node scaling"
echo "2. Implement Vertical Pod Autoscaler for right-sizing"
echo "3. Use spot instances for non-critical workloads"
echo "4. Review and cleanup unused resources regularly"
echo "5. Consider using smaller node instance types with higher density"
```

### Cluster Autoscaler Configuration

Create `cluster-autoscaler.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  labels:
    app: cluster-autoscaler
spec:
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.21.0
        name: cluster-autoscaler
        resources:
          limits:
            cpu: 100m
            memory: 300Mi
          requests:
            cpu: 100m
            memory: 300Mi
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/production
        - --balance-similar-node-groups
        - --scale-down-enabled=true
        - --scale-down-delay-after-add=10m
        - --scale-down-unneeded-time=10m
        - --scale-down-utilization-threshold=0.5
        - --max-node-provision-time=15m
        env:
        - name: AWS_REGION
          value: us-west-2
```

## Production Readiness Assessment

### Readiness Checklist Script

Create `production-readiness-check.sh`:

```bash
#!/bin/bash

# Production Readiness Assessment
echo "=== Kubernetes Production Readiness Check ==="
echo "Assessment Date: $(date)"
echo

SCORE=0
MAX_SCORE=0

check_item() {
  local description="$1"
  local command="$2"
  local weight="$3"
  
  MAX_SCORE=$((MAX_SCORE + weight))
  
  echo -n "Checking: $description... "
  
  if eval "$command" &> /dev/null; then
    echo "✓ PASS"
    SCORE=$((SCORE + weight))
  else
    echo "✗ FAIL"
  fi
}

echo "Infrastructure Checks:"
echo "====================="

check_item "Multiple nodes available" "[ \$(kubectl get nodes --no-headers | wc -l) -gt 1 ]" 10
check_item "All nodes are Ready" "! kubectl get nodes --no-headers | grep -v Ready" 10
check_item "Control plane is HA" "[ \$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers | wc -l) -gt 2 ]" 15
check_item "etcd is external/HA" "kubectl get pods -n kube-system | grep etcd | wc -l | grep -q '[3-9]'" 15

echo -e "\nSecurity Checks:"
echo "==============="

check_item "RBAC is enabled" "kubectl auth can-i '*' '*' --as=system:anonymous | grep -q 'no'" 10
check_item "Pod Security Standards enabled" "kubectl get ns -o json | jq -e '.items[] | select(.metadata.labels[\"pod-security.kubernetes.io/enforce\"])'" 10
check_item "Network policies exist" "[ \$(kubectl get networkpolicies --all-namespaces --no-headers | wc -l) -gt 0 ]" 10
check_item "No privileged pods" "! kubectl get pods --all-namespaces -o json | jq -e '.items[] | select(.spec.securityContext.privileged == true)'" 10

echo -e "\nApplication Checks:"
echo "=================="

check_item "Health checks configured" "kubectl get pods --all-namespaces -o json | jq -e '.items[] | select(.spec.containers[].livenessProbe)'" 10
check_item "Resource limits set" "kubectl get pods --all-namespaces -o json | jq -e '.items[] | select(.spec.containers[].resources.limits)'" 10
check_item "HPA configured" "[ \$(kubectl get hpa --all-namespaces --no-headers | wc -l) -gt 0 ]" 5
check_item "PDB configured" "[ \$(kubectl get pdb --all-namespaces --no-headers | wc -l) -gt 0 ]" 5

echo -e "\nMonitoring Checks:"
echo "================="

check_item "Prometheus installed" "kubectl get pods -n monitoring | grep prometheus" 10
check_item "Grafana installed" "kubectl get pods -n monitoring | grep grafana" 5
check_item "Alert manager configured" "kubectl get pods -n monitoring | grep alertmanager" 10
check_item "Log aggregation setup" "kubectl get pods -n kube-system | grep -E '(fluentd|fluent-bit|filebeat)'" 10

echo -e "\nBackup Checks:"
echo "============="

check_item "Backup solution installed" "kubectl get pods --all-namespaces | grep -E '(velero|ark)'" 15
check_item "Backup schedules configured" "[ \$(kubectl get schedule --all-namespaces --no-headers | wc -l) -gt 0 ]" 10
check_item "etcd backup configured" "systemctl is-active etcd-backup" 15

echo -e "\n=== Assessment Results ==="
echo "Score: $SCORE / $MAX_SCORE"
PERCENTAGE=$((SCORE * 100 / MAX_SCORE))
echo "Percentage: $PERCENTAGE%"

if [ $PERCENTAGE -ge 90 ]; then
  echo "Status: ✓ PRODUCTION READY"
elif [ $PERCENTAGE -ge 70 ]; then
  echo "Status: ⚠ MOSTLY READY (Some improvements needed)"
elif [ $PERCENTAGE -ge 50 ]; then
  echo "Status: ⚠ PARTIALLY READY (Significant improvements needed)"
else
  echo "Status: ✗ NOT PRODUCTION READY (Major issues to address)"
fi

echo -e "\nRecommendations based on failed checks above."
```

## Next Steps in Your Kubernetes Journey

### Learning Path Progression

1. **Advanced Kubernetes Concepts**
   - Custom Resource Definitions (CRDs)
   - Operators and Controllers
   - Admission Controllers
   - Service Mesh (Istio, Linkerd)

2. **Platform Engineering**
   - Internal Developer Platforms
   - Multi-cluster management
   - GitOps at scale
   - Policy as Code

3. **Cloud Native Ecosystem**
   - CNCF Landscape exploration
   - Serverless (Knative)
   - Event-driven architectures
   - Observability (OpenTelemetry)

4. **Specialized Areas**
   - Machine Learning on Kubernetes
   - Data processing (Spark, Flink)
   - Edge computing
   - IoT deployments

### Certification Paths

1. **Certified Kubernetes Administrator (CKA)**
   - Focus: Cluster administration and troubleshooting
   - Good for: Platform engineers, SREs

2. **Certified Kubernetes Application Developer (CKAD)**
   - Focus: Application development and deployment
   - Good for: Developers, DevOps engineers

3. **Certified Kubernetes Security Specialist (CKS)**
   - Focus: Kubernetes security practices
   - Good for: Security engineers, compliance specialists

### Community Engagement

- **Join Kubernetes Slack**: https://slack.k8s.io/
- **Attend KubeCon**: The premier Kubernetes conference
- **Contribute to projects**: Start with documentation
- **Local meetups**: Find Kubernetes meetups in your area
- **Special Interest Groups (SIGs)**: Join relevant SIGs

### Recommended Resources

**Books:**
- "Kubernetes: Up and Running" by Kelsey Hightower
- "Kubernetes Patterns" by Bilgin Ibryam
- "Production Kubernetes" by Josh Rosso

**Online Courses:**
- Kubernetes the Hard Way (Kelsey Hightower)
- Linux Academy/A Cloud Guru Kubernetes courses
- Udemy Kubernetes courses

**Practice Platforms:**
- Katacoda Kubernetes scenarios
- Play with Kubernetes (labs.play-with-k8s.com)
- Kubernetes Learning Environment (KLE)

## Final Project: Deploy a Production-Ready Application

Create a complete production deployment:

```bash
# Final project deployment script
#!/bin/bash

echo "Deploying production-ready Todo application..."

# Create production namespace
kubectl create namespace todo-production

# Apply all configurations
kubectl apply -f production-storage.yaml
kubectl apply -f ha-application.yaml
kubectl apply -f monitoring-stack.yaml
kubectl apply -f logging-stack.yaml
kubectl apply -f backup-strategy.yaml

# Wait for deployment
kubectl rollout status deployment/webapp-ha -n todo-production

# Run production readiness check
./production-readiness-check.sh

echo "Production deployment completed!"
echo "Access your application at: https://todo.example.com"
```

## Conclusion

Congratulations! You've completed your journey from Kubernetes beginner to production-ready practitioner. You now have:

✅ **Solid Foundation**: Understanding of core Kubernetes concepts
✅ **Practical Skills**: Hands-on experience with real deployments
✅ **Production Knowledge**: Best practices for running workloads at scale
✅ **Security Awareness**: Understanding of Kubernetes security landscape
✅ **Operational Excellence**: Monitoring, logging, and troubleshooting skills
✅ **DevOps Integration**: CI/CD and GitOps practices
✅ **Future Roadmap**: Clear path for continued learning

### Key Principles to Remember

1. **Start Small**: Begin with simple deployments and gradually add complexity
2. **Security First**: Always consider security implications
3. **Monitor Everything**: Observability is crucial for production systems
4. **Automate Relentlessly**: Reduce manual operations through automation
5. **Plan for Failure**: Design resilient systems that can handle failures
6. **Keep Learning**: Kubernetes ecosystem evolves rapidly
7. **Community Matters**: Engage with the community for support and knowledge

### Your Kubernetes Journey Continues

This textbook has provided you with a comprehensive foundation, but your Kubernetes journey is just beginning. The technology continues to evolve, and there's always more to learn. Stay curious, keep experimenting, and don't hesitate to contribute back to the community.

**Welcome to the world of Kubernetes!** 🚀

## Cleaning Up

```bash
# Clean up all resources created during the course
kubectl delete namespace rbac-demo netpol-demo secure-namespace todo-production
kubectl delete -f ha-application.yaml
kubectl delete -f monitoring-stack.yaml
kubectl delete -f logging-stack.yaml
kubectl delete -f backup-strategy.yaml
```

## Commands Reference

| Command | Purpose |
|---------|---------|
| `kubectl rollout status deployment/<name>` | Check deployment rollout |
| `kubectl scale deployment <name> --replicas=<n>` | Scale deployment |
| `kubectl top nodes` | Node resource usage |
| `kubectl get events --sort-by=.metadata.creationTimestamp` | Recent events |
| `kubectl describe node <name>` | Node details |
| `kubectl cordon <node>` | Mark node unschedulable |
| `kubectl drain <node>` | Drain node for maintenance |
| `kubectl uncordon <node>` | Mark node schedulable |

---

**🎉 Congratulations!** You have successfully completed the **Kubernetes for Complete Beginners with Minikube** textbook. You're now ready to deploy and manage applications in production Kubernetes environments!