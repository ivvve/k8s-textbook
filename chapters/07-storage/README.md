# Chapter 7: Persistent Volumes and Storage

## Learning Objectives

By the end of this chapter, you will understand:
- Why persistent storage is needed in Kubernetes
- The difference between Volumes, Persistent Volumes, and Persistent Volume Claims
- How to create and use persistent storage for applications
- Storage classes and dynamic provisioning
- Best practices for data persistence in Kubernetes

## The Problem: Data Persistence in Containers

Containers and Pods are ephemeral by design - when they're deleted, all data inside them is lost. This creates challenges for:

1. **Databases**: Need to persist data between Pod restarts
2. **File uploads**: User-uploaded content must survive Pod lifecycle
3. **Logs and metrics**: Historical data collection
4. **Shared data**: Multiple Pods accessing the same data
5. **Application state**: Stateful applications requiring persistent storage

## Kubernetes Storage Concepts

### 1. Volumes
**Volumes** are directories accessible to containers in a Pod. They exist as long as the Pod exists.

### 2. Persistent Volumes (PV)
**Persistent Volumes** are cluster-level storage resources that exist independently of Pods.

### 3. Persistent Volume Claims (PVC)
**Persistent Volume Claims** are requests for storage by users/Pods.

### Storage Analogy
Think of storage like a library system:
- **Volume**: A temporary desk you use while in the library
- **Persistent Volume**: Books on the library shelves (permanent storage)
- **Persistent Volume Claim**: Your library card request for specific books

## Volume Types

### 1. emptyDir
Temporary storage that exists for the Pod's lifetime:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-pod
spec:
  containers:
  - name: app
    image: nginx:1.21
    volumeMounts:
    - name: cache-volume
      mountPath: /tmp/cache
  - name: sidecar
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: cache-volume
      mountPath: /shared-data
  volumes:
  - name: cache-volume
    emptyDir: {}
```

**Use cases**:
- Temporary files and caches
- Shared data between containers in a Pod
- Scratch space for computations

### 2. hostPath
Mount files/directories from the host node:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-pod
spec:
  containers:
  - name: app
    image: nginx:1.21
    volumeMounts:
    - name: host-volume
      mountPath: /host-data
  volumes:
  - name: host-volume
    hostPath:
      path: /tmp/kubernetes
      type: DirectoryOrCreate
```

**Use cases**:
- Access node's filesystem
- Development and testing
- System-level access (use with caution)

### 3. configMap and secret
Mount ConfigMaps and Secrets as volumes (covered in Chapter 6).

## Persistent Volumes (PV)

A **Persistent Volume** is a piece of storage in the cluster that has been provisioned by an administrator or dynamically created.

### Creating a Persistent Volume

Create `my-pv.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /tmp/my-pv-data
```

```bash
# Create the PV
kubectl apply -f my-pv.yaml

# Check PV status
kubectl get pv
kubectl describe pv my-pv
```

### PV Access Modes

1. **ReadWriteOnce (RWO)**: Read-write by a single node
2. **ReadOnlyMany (ROX)**: Read-only by many nodes
3. **ReadWriteMany (RWX)**: Read-write by many nodes

### PV Reclaim Policies

1. **Retain**: Manual reclamation (data preserved)
2. **Recycle**: Basic scrub (deprecated)
3. **Delete**: Associated storage asset deleted

## Persistent Volume Claims (PVC)

A **Persistent Volume Claim** is a request for storage by a user.

### Creating a Persistent Volume Claim

Create `my-pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
```

```bash
# Create the PVC
kubectl apply -f my-pvc.yaml

# Check PVC status
kubectl get pvc
kubectl describe pvc my-pvc

# Verify PV binding
kubectl get pv
```

### PVC States

1. **Pending**: No suitable PV found
2. **Bound**: PVC bound to a PV
3. **Lost**: PV no longer exists

## Using Persistent Volumes in Pods

### Basic Usage

Create `pod-with-pvc.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-storage
spec:
  containers:
  - name: app
    image: nginx:1.21
    volumeMounts:
    - name: persistent-storage
      mountPath: /usr/share/nginx/html
  volumes:
  - name: persistent-storage
    persistentVolumeClaim:
      claimName: my-pvc
```

```bash
# Create the Pod
kubectl apply -f pod-with-pvc.yaml

# Verify the Pod is running
kubectl get pods

# Test persistence
kubectl exec pod-with-storage -- sh -c 'echo "Hello from persistent storage!" > /usr/share/nginx/html/index.html'

# Access the content
kubectl port-forward pod-with-storage 8080:80
# Visit http://localhost:8080 to see the content
```

### Testing Data Persistence

```bash
# Delete the Pod
kubectl delete pod pod-with-storage

# Create a new Pod with the same PVC
kubectl apply -f pod-with-pvc.yaml

# Check if data persists
kubectl port-forward pod-with-storage 8080:80
# Visit http://localhost:8080 - content should still be there!
```

## Practical Example: MySQL Database with Persistent Storage

Let's create a MySQL database that persists data across Pod restarts.

### Step 1: Create PV and PVC for MySQL

Create `mysql-storage.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv
spec:
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /tmp/mysql-data

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```

### Step 2: Create MySQL Deployment

Create `mysql-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-deployment
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
        - name: MYSQL_USER
          value: "testuser"
        - name: MYSQL_PASSWORD
          value: "testpassword"
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc
```

### Step 3: Create MySQL Service

Create `mysql-service.yaml`:

```yaml
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
  type: ClusterIP
```

### Step 4: Deploy Everything

```bash
# Create storage
kubectl apply -f mysql-storage.yaml

# Create deployment and service
kubectl apply -f mysql-deployment.yaml
kubectl apply -f mysql-service.yaml

# Verify everything is running
kubectl get pv,pvc
kubectl get pods
kubectl get services
```

### Step 5: Test Database Persistence

```bash
# Access MySQL and create some data
kubectl run mysql-client --image=mysql:8.0 -it --rm --restart=Never \
  -- mysql -h mysql-service -u testuser -ptestpassword testdb

# Inside MySQL client:
# CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100));
# INSERT INTO users (name) VALUES ('Alice'), ('Bob'), ('Charlie');
# SELECT * FROM users;
# EXIT;

# Delete the MySQL Pod to simulate failure
kubectl delete pod -l app=mysql

# Wait for new Pod to start
kubectl get pods -w

# Access database again to verify data persistence
kubectl run mysql-client --image=mysql:8.0 -it --rm --restart=Never \
  -- mysql -h mysql-service -u testuser -ptestpassword testdb

# Inside MySQL client:
# SELECT * FROM users;  -- Data should still be there!
# EXIT;
```

## Storage Classes

**Storage Classes** provide a way to describe the "classes" of storage available. They enable dynamic provisioning of PVs.

### Default Storage Class in minikube

```bash
# Check available storage classes in minikube
kubectl get storageclass

# Check default storage class
kubectl get storageclass -o yaml
```

### Using Dynamic Provisioning

Create `dynamic-pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard  # minikube's default storage class
```

```bash
# Create PVC with dynamic provisioning
kubectl apply -f dynamic-pvc.yaml

# Watch as PV is automatically created
kubectl get pvc
kubectl get pv
```

### Custom Storage Class

Create `custom-storage-class.yaml`:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-storage
provisioner: k8s.io/minikube-hostpath
parameters:
  type: fast
reclaimPolicy: Delete
allowVolumeExpansion: true
```

## StatefulSets for Persistent Storage

For applications requiring stable, persistent storage, use **StatefulSets** instead of Deployments.

### StatefulSet Example

Create `web-statefulset.yaml`:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web-statefulset
spec:
  serviceName: web-service
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
        volumeMounts:
        - name: web-storage
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: web-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 100Mi

---
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  clusterIP: None  # Headless service
  selector:
    app: web
  ports:
  - port: 80
```

```bash
# Create StatefulSet
kubectl apply -f web-statefulset.yaml

# Check StatefulSet and PVCs
kubectl get statefulset
kubectl get pvc
kubectl get pods
```

### StatefulSet Characteristics

1. **Stable network identity**: Pods get predictable names
2. **Stable storage**: Each Pod gets its own PV
3. **Ordered deployment**: Pods created/updated in order
4. **Ordered scaling**: Scale operations happen in order

## Volume Snapshots

**Volume Snapshots** allow you to create point-in-time copies of PVs.

### Creating a Volume Snapshot

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: mysql-snapshot
spec:
  volumeSnapshotClassName: csi-hostpath-snapclass
  source:
    persistentVolumeClaimName: mysql-pvc
```

**Note**: Volume snapshots require CSI drivers and may not be available in all minikube configurations.

## Storage Best Practices

### 1. Choose Appropriate Volume Types

```yaml
# For temporary data
volumes:
- name: temp-storage
  emptyDir: {}

# For configuration files
volumes:
- name: config
  configMap:
    name: app-config

# For persistent data
volumes:
- name: data-storage
  persistentVolumeClaim:
    claimName: app-data-pvc
```

### 2. Use Appropriate Access Modes

```yaml
# Database storage (single writer)
spec:
  accessModes:
    - ReadWriteOnce

# Shared configuration (multiple readers)
spec:
  accessModes:
    - ReadOnlyMany

# Shared workspace (multiple writers, if supported)
spec:
  accessModes:
    - ReadWriteMany
```

### 3. Set Resource Requests Appropriately

```yaml
spec:
  resources:
    requests:
      storage: 10Gi  # Request what you actually need
```

### 4. Use Storage Classes for Production

```yaml
spec:
  storageClassName: fast-ssd  # Production storage class
  resources:
    requests:
      storage: 100Gi
```

### 5. Plan for Backup and Recovery

```yaml
# Use labels for backup identification
metadata:
  labels:
    backup-policy: daily
    retention: 30days
```

## Troubleshooting Storage Issues

### PVC Stuck in Pending

```bash
# Check PVC status
kubectl describe pvc <pvc-name>

# Check available PVs
kubectl get pv

# Check storage classes
kubectl get storageclass
```

**Common causes**:
- No available PV matches PVC requirements
- Insufficient storage capacity
- Access mode mismatch
- Storage class issues

### Pod Can't Mount Volume

```bash
# Check Pod events
kubectl describe pod <pod-name>

# Check PVC binding
kubectl get pvc

# Check node storage capacity
kubectl describe node <node-name>
```

### Data Not Persisting

```bash
# Verify PVC is bound
kubectl get pvc

# Check volume mount paths
kubectl describe pod <pod-name>

# Verify PV reclaim policy
kubectl describe pv <pv-name>
```

## Multi-Container Storage Sharing

Example of containers sharing storage within a Pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared-storage-pod
spec:
  containers:
  - name: writer
    image: busybox
    command: ["sh", "-c", "while true; do echo $(date) >> /shared/data.log; sleep 5; done"]
    volumeMounts:
    - name: shared-volume
      mountPath: /shared
  - name: reader
    image: busybox
    command: ["sh", "-c", "while true; do tail -f /shared/data.log; sleep 1; done"]
    volumeMounts:
    - name: shared-volume
      mountPath: /shared
  volumes:
  - name: shared-volume
    persistentVolumeClaim:
      claimName: shared-pvc
```

## Backup Strategies

### 1. Volume Snapshots

```bash
# Create snapshot
kubectl apply -f volume-snapshot.yaml

# List snapshots  
kubectl get volumesnapshot

# Restore from snapshot
kubectl apply -f restore-from-snapshot.yaml
```

### 2. Application-Level Backups

```bash
# Database backup example
kubectl exec mysql-pod -- mysqldump -u root -p database_name > backup.sql

# File system backup
kubectl exec app-pod -- tar -czf /backup/data.tar.gz /app/data
```

## Cleaning Up

```bash
# Delete Pods first
kubectl delete pod pod-with-storage
kubectl delete deployment mysql-deployment

# Delete PVCs (this may delete PVs with Delete reclaim policy)
kubectl delete pvc my-pvc mysql-pvc dynamic-pvc

# Delete PVs with Retain policy manually
kubectl delete pv my-pv mysql-pv

# Delete StatefulSet and its PVCs
kubectl delete statefulset web-statefulset
kubectl delete pvc -l app=web

# Delete services
kubectl delete service mysql-service web-service
```

## Hands-On Exercises

### Exercise 1: Create Persistent Web Server

1. Create a PV and PVC for web content
2. Deploy nginx with persistent storage
3. Add custom content to the web server
4. Delete and recreate the Pod to verify persistence

### Exercise 2: Database with Backup

1. Deploy PostgreSQL with persistent storage
2. Create some test data
3. Create a backup of the database
4. Simulate Pod failure and verify data recovery

### Exercise 3: Shared Storage

1. Create a PVC that supports ReadWriteMany (if available)
2. Deploy multiple Pods sharing the same storage
3. Test concurrent read/write operations

## Key Takeaways

1. **Volumes are Pod-scoped** - Exist only as long as the Pod exists
2. **PVs are cluster resources** - Independent of Pod lifecycle
3. **PVCs request storage** - Abstract way to consume storage
4. **Storage Classes enable dynamic provisioning** - Automatic PV creation
5. **StatefulSets provide stable storage** - For stateful applications
6. **Choose appropriate access modes** - Based on application requirements
7. **Plan for data persistence** - Consider backup and recovery strategies

## Commands Reference

| Command | Purpose |
|---------|---------|
| `kubectl get pv` | List Persistent Volumes |
| `kubectl get pvc` | List Persistent Volume Claims |
| `kubectl get storageclass` | List Storage Classes |
| `kubectl describe pv <name>` | PV details |
| `kubectl describe pvc <name>` | PVC details |
| `kubectl patch pvc <name> -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'` | Expand PVC |
| `kubectl get volumesnapshot` | List volume snapshots |
| `kubectl delete pvc <name>` | Delete PVC |

---

**Next Chapter**: [Namespaces and Resource Management](../08-namespaces/) - Learn how to organize resources and manage multi-environment setups in Kubernetes.