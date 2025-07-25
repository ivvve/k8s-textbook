# Chapter 6: ConfigMaps and Secrets

## Learning Objectives

By the end of this chapter, you will understand:
- Why configuration should be externalized from application code
- How to create and use ConfigMaps for configuration data
- How to create and use Secrets for sensitive information
- Different ways to consume ConfigMaps and Secrets in Pods
- Best practices for configuration management

## The Problem: Hardcoded Configuration

Applications typically need configuration data like:
- Database connection strings
- API endpoints
- Feature flags
- Environment-specific settings
- Credentials and API keys

**Problems with hardcoded configuration**:
1. **Security risks**: Credentials in source code
2. **Inflexibility**: Need to rebuild images for config changes
3. **Environment coupling**: Same image can't work across environments
4. **Version control issues**: Sensitive data in repositories

## The Twelve-Factor App Principle

The [Twelve-Factor App](https://12factor.net/) methodology recommends:
> **Config**: Store config in the environment

Kubernetes provides two main objects for this:
- **ConfigMaps**: For non-sensitive configuration data
- **Secrets**: For sensitive information like passwords and API keys

## ConfigMaps

A **ConfigMap** is a Kubernetes object that stores configuration data as key-value pairs.

### ConfigMap Characteristics

1. **Plain text data**: Stores non-sensitive configuration
2. **Key-value format**: Simple key-value pairs
3. **Multiple data sources**: From literals, files, or directories
4. **Decoupled from Pods**: Configuration separate from application logic

### Creating ConfigMaps

#### Method 1: From Literal Values

```bash
# Create ConfigMap with literal values
kubectl create configmap app-config \
  --from-literal=database_host=mysql-service \
  --from-literal=database_port=3306 \
  --from-literal=app_mode=production \
  --from-literal=debug_enabled=false

# View the ConfigMap
kubectl get configmap app-config
kubectl describe configmap app-config
```

#### Method 2: From Files

Create a configuration file `app.properties`:

```properties
database.host=mysql-service
database.port=3306
app.mode=production
debug.enabled=false
log.level=info
```

```bash
# Create ConfigMap from file
kubectl create configmap app-config-file --from-file=app.properties

# View the ConfigMap
kubectl describe configmap app-config-file
```

#### Method 3: From Directory

```bash
# Create ConfigMap from all files in a directory
mkdir config-files
echo "database_host=mysql-service" > config-files/database.conf
echo "redis_host=redis-service" > config-files/redis.conf

kubectl create configmap app-config-dir --from-file=config-files/

# View the ConfigMap
kubectl describe configmap app-config-dir
```

#### Method 4: Using YAML Declaration

Create `configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-yaml
data:
  database_host: "mysql-service"
  database_port: "3306"
  app_mode: "production"
  debug_enabled: "false"
  app.properties: |
    database.host=mysql-service
    database.port=3306
    app.mode=production
    debug.enabled=false
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
```

```bash
# Create ConfigMap from YAML
kubectl apply -f configmap.yaml

# View the ConfigMap
kubectl get configmap app-config-yaml -o yaml
```

## Using ConfigMaps in Pods

### Method 1: Environment Variables

#### All keys as environment variables:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod-env-all
spec:
  containers:
  - name: app
    image: nginx:1.21
    envFrom:
    - configMapRef:
        name: app-config-yaml
```

#### Specific keys as environment variables:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod-env-specific
spec:
  containers:
  - name: app
    image: nginx:1.21
    env:
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config-yaml
          key: database_host
    - name: DATABASE_PORT
      valueFrom:
        configMapKeyRef:
          name: app-config-yaml
          key: database_port
```

### Method 2: Volume Mounts

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod-volume
spec:
  containers:
  - name: app
    image: nginx:1.21
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: app-config-yaml
```

#### Mount specific keys:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod-volume-specific
spec:
  containers:
  - name: app
    image: nginx:1.21
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: app-config-yaml
      items:
      - key: app.properties
        path: application.properties
      - key: nginx.conf
        path: nginx/nginx.conf
```

## Secrets

A **Secret** is similar to a ConfigMap but specifically designed for sensitive data.

### Secret Characteristics

1. **Base64 encoded**: Data is encoded (not encrypted)
2. **Memory-only storage**: Stored in tmpfs on nodes
3. **Access control**: Can be restricted with RBAC
4. **Size limit**: Maximum 1MB per Secret

### Types of Secrets

1. **generic**: Arbitrary user-defined data
2. **docker-registry**: Docker registry credentials
3. **tls**: TLS certificates

### Creating Secrets

#### Method 1: From Literal Values

```bash
# Create Secret with literal values
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=secretpassword123 \
  --from-literal=api-key=abc123xyz789

# View the Secret (note: values are base64 encoded)
kubectl get secret db-credentials -o yaml
```

#### Method 2: From Files

Create credential files:

```bash
echo -n 'admin' > username.txt
echo -n 'secretpassword123' > password.txt

# Create Secret from files
kubectl create secret generic db-credentials-file \
  --from-file=username.txt \
  --from-file=password.txt

# Clean up files
rm username.txt password.txt
```

#### Method 3: Using YAML Declaration

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials-yaml
type: Opaque
data:
  username: YWRtaW4=           # base64 encoded 'admin'
  password: c2VjcmV0cGFzc3dvcmQxMjM=  # base64 encoded 'secretpassword123'
```

```bash
# Encode values manually
echo -n 'admin' | base64
echo -n 'secretpassword123' | base64

# Create Secret from YAML
kubectl apply -f secret.yaml
```

#### Method 4: Using stringData (Easier)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials-easy
type: Opaque
stringData:
  username: admin
  password: secretpassword123
  api-key: abc123xyz789
```

## Using Secrets in Pods

### Method 1: Environment Variables

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-secrets-env
spec:
  containers:
  - name: app
    image: nginx:1.21
    env:
    - name: DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: db-credentials-easy
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials-easy
          key: password
    - name: API_KEY
      valueFrom:
        secretKeyRef:
          name: db-credentials-easy
          key: api-key
    envFrom:
    - configMapRef:
        name: app-config-yaml
```

### Method 2: Volume Mounts

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-secrets-volume
spec:
  containers:
  - name: app
    image: nginx:1.21
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: db-credentials-easy
```

## Practical Example: WordPress + MySQL with ConfigMaps and Secrets

Let's enhance the WordPress + MySQL example from Chapter 4 by properly managing configuration with ConfigMaps and Secrets. This demonstrates how to externalize database configuration and credentials.

### Why Use ConfigMaps and Secrets Here?

In Chapter 4, we hardcoded database configuration directly in the Deployment YAML:
- Database host, port, and name were hardcoded as environment variables
- Passwords were embedded in plain text in the YAML files

This approach has problems:
- **Security risk**: Passwords visible in YAML files
- **Inflexibility**: Need to edit YAML files to change configuration
- **Environment coupling**: Same YAML can't work across dev/staging/prod

### Step 1: Create ConfigMap for Database Configuration

Create `wordpress-config.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: wordpress-config
data:
  # Database connection settings (non-sensitive)
  db_host: "mysql-service"
  db_port: "3306"
  db_name: "wordpress"
  # WordPress application settings
  wp_debug: "false"
  upload_max_filesize: "64M"
  memory_limit: "256M"
```

### Step 2: Create Secret for Database Credentials

Create `wordpress-secrets.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: wordpress-secrets
type: Opaque
stringData:
  # MySQL credentials
  mysql_root_password: "rootpassword123"
  mysql_user: "wpuser"
  mysql_password: "wppassword456"
  # WordPress database credentials (must match MySQL)
  db_user: "wpuser"
  db_password: "wppassword456"
```

### Step 3: Create Updated Deployments Using ConfigMaps and Secrets

Now let's update our WordPress and MySQL deployments to use ConfigMaps and Secrets instead of hardcoded values.

Create `wordpress-mysql-with-config.yaml`:

```yaml
# MySQL Deployment using ConfigMap and Secrets
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  labels:
    app: mysql
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
        # Database configuration from ConfigMap
        - name: MYSQL_DATABASE
          valueFrom:
            configMapKeyRef:
              name: wordpress-config
              key: db_name
        # Sensitive data from Secrets
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: wordpress-secrets
              key: mysql_root_password
        - name: MYSQL_USER
          valueFrom:
            secretKeyRef:
              name: wordpress-secrets
              key: mysql_user
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: wordpress-secrets
              key: mysql_password
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-storage
        emptyDir: {}

---
# WordPress Deployment using ConfigMap and Secrets
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  labels:
    app: wordpress
spec:
  replicas: 2
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
      - name: wordpress
        image: wordpress:6.3-apache
        env:
        # Database connection from ConfigMap (non-sensitive)
        - name: WORDPRESS_DB_HOST
          valueFrom:
            configMapKeyRef:
              name: wordpress-config
              key: db_host
        - name: WORDPRESS_DB_NAME
          valueFrom:
            configMapKeyRef:
              name: wordpress-config
              key: db_name
        # Database credentials from Secrets
        - name: WORDPRESS_DB_USER
          valueFrom:
            secretKeyRef:
              name: wordpress-secrets
              key: db_user
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: wordpress-secrets
              key: db_password
        # WordPress configuration from ConfigMap
        - name: WORDPRESS_DEBUG
          valueFrom:
            configMapKeyRef:
              name: wordpress-config
              key: wp_debug
        ports:
        - containerPort: 80
        volumeMounts:
        - name: wordpress-storage
          mountPath: /var/www/html
      volumes:
      - name: wordpress-storage
        emptyDir: {}

---
# Services (same as Chapter 4)
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
  type: ClusterIP

---
apiVersion: v1
kind: Service
metadata:
  name: wordpress-service
  labels:
    app: wordpress
spec:
  selector:
    app: wordpress
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
  type: NodePort
```

### Step 4: Deploy Everything

```bash
# Create ConfigMap and Secrets first
kubectl apply -f wordpress-config.yaml
kubectl apply -f wordpress-secrets.yaml

# Create Deployments and Services
kubectl apply -f wordpress-mysql-with-config.yaml

# Verify everything is running
kubectl get configmaps
kubectl get secrets
kubectl get deployments
kubectl get services
kubectl get pods
```

### Step 5: Verify Configuration

```bash
# Check environment variables in MySQL pod
kubectl exec -it deployment/mysql -- env | grep -E "(MYSQL_DATABASE|MYSQL_USER)"

# Check environment variables in WordPress pod  
kubectl exec -it deployment/wordpress -- env | grep -E "(WORDPRESS_DB_HOST|WORDPRESS_DB_NAME|WORDPRESS_DEBUG)"

# Test the application
minikube service wordpress-service --url
```

### Key Benefits of This Approach

**Security Improvements:**
- Passwords are stored in Secrets (base64 encoded, not plain text)
- ConfigMaps contain only non-sensitive configuration
- Secrets can be managed separately with different access controls

**Flexibility:**
- Database host can be changed without rebuilding images
- Different environments can use different ConfigMaps/Secrets
- Configuration updates don't require code changes

**Comparison with Chapter 4 Hardcoded Version:**

| Aspect | Chapter 4 (Hardcoded) | Chapter 6 (ConfigMaps/Secrets) |
|--------|----------------------|--------------------------------|
| **Security** | Passwords in plain YAML | Passwords in Secrets |
| **Flexibility** | Need to edit YAML files | Update ConfigMaps/Secrets |
| **Environment Support** | Same YAML for all envs | Different configs per env |
| **Secret Management** | Manual password handling | Kubernetes-managed secrets |

## Updating Configuration

### Updating ConfigMaps

```bash
# Update ConfigMap
kubectl patch configmap webapp-config --patch '{"data":{"log_level":"debug"}}'

# Or edit directly
kubectl edit configmap webapp-config

# Note: Pods need restart to pick up env var changes
kubectl rollout restart deployment webapp-deployment
```

### Updating Secrets

```bash
# Update Secret
kubectl patch secret webapp-secrets --patch '{"stringData":{"api_key":"new_api_key_xyz"}}'

# Or edit directly (remember base64 encoding)
kubectl edit secret webapp-secrets

# Restart deployment
kubectl rollout restart deployment webapp-deployment
```

## Docker Registry Secrets

For private container registries:

```bash
# Create docker-registry secret
kubectl create secret docker-registry my-registry-secret \
  --docker-server=my-registry.com \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=my-email@example.com

# Use in Pod spec
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: private-image-pod
spec:
  containers:
  - name: app
    image: my-registry.com/private/app:latest
  imagePullSecrets:
  - name: my-registry-secret
```

## TLS Secrets

For HTTPS certificates:

```bash
# Create TLS secret from certificate files
kubectl create secret tls my-tls-secret \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-tls-secret
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
```

## Best Practices

### 1. Security

- **Never commit secrets to version control**
- **Use Secrets for sensitive data, ConfigMaps for non-sensitive**
- **Limit Secret access with RBAC**
- **Consider external secret management systems**

### 2. Organization

```yaml
# Good: Environment-specific naming
metadata:
  name: webapp-config-prod
  name: webapp-secrets-prod

# Good: Consistent labeling
metadata:
  labels:
    app: webapp
    environment: production
    component: config
```

### 3. Configuration Structure

```yaml
# Good: Logical grouping
data:
  database.host: "mysql-service"
  database.port: "3306"
  redis.host: "redis-service"
  redis.port: "6379"

# Good: File-based configuration
data:
  application.yaml: |
    database:
      host: mysql-service
      port: 3306
    redis:
      host: redis-service
      port: 6379
```

### 4. Updates and Rollouts

- **Use immutable ConfigMaps/Secrets when possible**
- **Version your configuration objects**
- **Plan for rollout restarts when updating config**

## Troubleshooting

### Common Issues

#### 1. Pod not finding ConfigMap/Secret

```bash
# Check if ConfigMap/Secret exists
kubectl get configmaps
kubectl get secrets

# Check Pod events
kubectl describe pod <pod-name>
```

#### 2. Environment variables not updated

```bash
# Environment variables require pod restart
kubectl rollout restart deployment <deployment-name>

# Check current env vars
kubectl exec <pod-name> -- env
```

#### 3. File mount issues

```bash
# Check volume mounts
kubectl describe pod <pod-name>

# Check mounted files
kubectl exec <pod-name> -- ls -la /mounted/path/
```

## Hands-On Exercises

### Exercise 1: Create ConfigMap from Properties File

1. Create a properties file with database configuration
2. Create ConfigMap from the file
3. Use it in a Pod as environment variables

### Exercise 2: Secret Management

1. Create a Secret with database credentials
2. Mount it as files in a Pod
3. Verify the files contain the correct data

### Exercise 3: Configuration Update

1. Create a Deployment with ConfigMap
2. Update the ConfigMap
3. Restart the Deployment to pick up changes

## Cleaning Up

```bash
# Delete ConfigMaps
kubectl delete configmap app-config app-config-file app-config-dir app-config-yaml webapp-config

# Delete Secrets
kubectl delete secret db-credentials db-credentials-file db-credentials-yaml db-credentials-easy webapp-secrets

# Delete Deployments
kubectl delete deployment webapp-deployment

# Delete Pods
kubectl delete pod --all
```

## Key Takeaways

1. **Externalize configuration** - Never hardcode config in container images
2. **Use ConfigMaps for non-sensitive data** - Database hosts, feature flags, etc.
3. **Use Secrets for sensitive data** - Passwords, API keys, certificates
4. **Multiple consumption methods** - Environment variables or file mounts
5. **Plan for updates** - Configuration changes often require Pod restarts
6. **Follow security best practices** - Proper access control and secret management

## Commands Reference

| Command | Purpose |
|---------|---------|
| `kubectl create configmap <name> --from-literal=<key>=<value>` | Create ConfigMap from literals |
| `kubectl create configmap <name> --from-file=<file>` | Create ConfigMap from file |
| `kubectl create secret generic <name> --from-literal=<key>=<value>` | Create Secret from literals |
| `kubectl get configmaps` | List ConfigMaps |
| `kubectl get secrets` | List Secrets |
| `kubectl describe configmap <name>` | ConfigMap details |
| `kubectl describe secret <name>` | Secret details |
| `kubectl edit configmap <name>` | Edit ConfigMap |
| `kubectl edit secret <name>` | Edit Secret |

---

**Next Chapter**: [Persistent Volumes and Storage](../07-storage/) - Learn how to manage persistent data and storage in Kubernetes.