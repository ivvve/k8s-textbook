# Appendix B: Troubleshooting Guide

## Common Issues and Solutions

This comprehensive troubleshooting guide covers the most common Kustomize issues, their root causes, and step-by-step solutions.

## Build Errors

### 1. "unable to find one of 'kustomization.yaml', 'kustomization.yml' or 'Kustomization'"

**Symptoms:**
```bash
$ kustomize build .
Error: unable to find one of 'kustomization.yaml', 'kustomization.yml' or 'Kustomization'
```

**Cause:** No kustomization file exists in the specified directory.

**Solutions:**
```bash
# Check current directory contents
ls -la

# Create kustomization.yaml
kustomize create

# Or create manually
cat > kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: []
EOF

# Check if file exists in parent directories
find . -name "kustomization.yaml" -o -name "kustomization.yml" -o -name "Kustomization"
```

### 2. "resource not found"

**Symptoms:**
```bash
$ kustomize build .
Error: accumulating resources: accumulation err='accumulating resources from 'deployment.yaml': open deployment.yaml: no such file or directory'
```

**Cause:** Referenced resource file doesn't exist or path is incorrect.

**Diagnosis:**
```bash
# List files in current directory
ls -la

# Check kustomization.yaml content
cat kustomization.yaml

# Verify resource paths
for resource in $(yq eval '.resources[]' kustomization.yaml); do
  echo "Checking: $resource"
  if [ -f "$resource" ]; then
    echo "✓ Found: $resource"
  else
    echo "✗ Missing: $resource"
  fi
done
```

**Solutions:**
```bash
# Remove non-existent resources
kustomize edit remove resource missing-file.yaml

# Add correct resource path
kustomize edit add resource correct-path/deployment.yaml

# Create missing resource file
touch deployment.yaml
```

### 3. "patch target not found"

**Symptoms:**
```bash
$ kustomize build .
Error: patch target not found: no matches for Id ~G_v1_Deployment|~X|wrong-name; failed to find unique target for patch
```

**Cause:** Patch references a resource that doesn't exist or has incorrect metadata.

**Diagnosis:**
```bash
# List all resources in base
kustomize build base | grep -E "^(kind|metadata):" -A 1

# Check patch target
cat patches/my-patch.yaml | head -10

# Verify resource names match
kustomize build base | yq eval 'select(.kind == "Deployment") | .metadata.name' -
```

**Solutions:**
```bash
# Fix patch target in kustomization.yaml
kustomize edit add patch --path my-patch.yaml --kind Deployment --name correct-name

# Or fix the patch file metadata
cat > patches/my-patch.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: correct-name  # Must match target resource
spec:
  replicas: 5
EOF
```

### 4. "cycle detected"

**Symptoms:**
```bash
$ kustomize build .
Error: cycle detected: base -> overlay -> base
```

**Cause:** Circular dependency between kustomization files.

**Diagnosis:**
```bash
# Check resource references
grep -r "resources:" . --include="*.yaml"

# Visualize dependencies
find . -name "kustomization.yaml" -exec echo "=== {} ===" \; -exec cat {} \;
```

**Solutions:**
```bash
# Remove circular reference
kustomize edit remove resource ../problematic-overlay

# Restructure directories to avoid cycles
mkdir -p new-structure/{base,overlays/env1,overlays/env2}
# Move files appropriately
```

## Patching Issues

### 5. Strategic Merge Patch Not Working

**Symptoms:**
```bash
# Patch seems to be ignored or has no effect
```

**Cause:** Patch structure doesn't match target resource structure.

**Diagnosis:**
```bash
# Compare original vs patched output
echo "=== ORIGINAL ==="
kustomize build base | yq eval 'select(.kind == "Deployment")' -

echo "=== PATCHED ==="
kustomize build overlay | yq eval 'select(.kind == "Deployment")' -

# Check patch file structure
cat patches/my-patch.yaml
```

**Solutions:**
```bash
# Ensure patch metadata matches target
apiVersion: apps/v1
kind: Deployment
metadata:
  name: exact-target-name  # Must match exactly
spec:
  replicas: 5

# Use correct strategic merge structure
# For containers, include name to merge by name:
spec:
  template:
    spec:
      containers:
      - name: app  # This identifies which container to patch
        image: nginx:1.21
```

### 6. Array Replacement Instead of Merge

**Symptoms:**
```bash
# Entire array gets replaced instead of merged
```

**Cause:** Strategic merge behavior varies by field type.

**Example Problem:**
```yaml
# This replaces entire containers array
spec:
  template:
    spec:
      containers:
      - name: new-container
        image: new-image
```

**Solutions:**
```yaml
# Include all containers you want to keep
spec:
  template:
    spec:
      containers:
      - name: existing-app      # Keep existing
        image: app:v2.0.0       # Update image
      - name: existing-proxy    # Keep existing
      - name: new-sidecar       # Add new
        image: sidecar:1.0.0
```

### 7. JSON Patch Syntax Errors

**Symptoms:**
```bash
$ kustomize build .
Error: json patch error: invalid character 'o' looking for beginning of value
```

**Cause:** Invalid JSON patch syntax.

**Diagnosis:**
```bash
# Validate JSON patch syntax
echo '[{"op": "replace", "path": "/spec/replicas", "value": 5}]' | jq .

# Check patch in kustomization.yaml
yq eval '.patches[]' kustomization.yaml
```

**Solutions:**
```bash
# Fix JSON syntax
kustomize edit add patch \
  --patch '[{"op": "replace", "path": "/spec/replicas", "value": 5}]' \
  --kind Deployment \
  --name myapp

# Use proper escaping in YAML
patches:
- patch: |
    [
      {"op": "replace", "path": "/spec/replicas", "value": 5}
    ]
  target:
    kind: Deployment
    name: myapp
```

## Configuration Generation Issues

### 8. ConfigMap/Secret Not Updating

**Symptoms:**
```bash
# ConfigMap content changes but pods don't restart
```

**Cause:** Hash suffix not changing, or deployment not referencing generated name.

**Diagnosis:**
```bash
# Check if hash suffix is generated
kubectl get configmaps -n your-namespace | grep your-configmap

# Check deployment references
kubectl get deployment your-app -o yaml | grep configMapKeyRef -A 5

# Compare kustomize output vs deployed resources
kustomize build . | yq eval 'select(.kind == "ConfigMap")' -
kubectl get configmap -o yaml
```

**Solutions:**
```bash
# Ensure configMapGenerator is used (not static ConfigMap)
configMapGenerator:
- name: app-config
  files:
  - config.properties

# Force hash regeneration by changing content
kustomize edit add configmap app-config --from-literal=timestamp="$(date)"

# Use generated name in deployment
envFrom:
- configMapRef:
    name: app-config  # Kustomize adds hash suffix automatically
```

### 9. "disableNameSuffixHash doesn't work"

**Symptoms:**
```bash
# Hash suffix still appears despite disableNameSuffixHash: true
```

**Cause:** Option syntax or placement is incorrect.

**Working Example:**
```yaml
configMapGenerator:
- name: static-config
  literals:
  - VERSION=1.0.0
  options:
    disableNameSuffixHash: true
```

### 10. Secret Generation Fails

**Symptoms:**
```bash
$ kustomize build .
Error: could not read secret file: open secrets/password: no such file or directory
```

**Cause:** Referenced secret file doesn't exist.

**Solutions:**
```bash
# Check file existence
ls -la secrets/

# Create missing secret file
echo "mysecretpassword" > secrets/password

# Use literal instead of file
kustomize edit add secret app-secrets --from-literal=password=mysecretpassword

# Use environment variable
export SECRET_PASSWORD=mysecretpassword
kustomize edit add secret app-secrets --from-literal=password=${SECRET_PASSWORD}
```

## Namespace and Naming Issues

### 11. Resources Created in Wrong Namespace

**Symptoms:**
```bash
# Resources appear in default namespace instead of intended namespace
```

**Diagnosis:**
```bash
# Check namespace setting
yq eval '.namespace' kustomization.yaml

# Check built resources
kustomize build . | grep namespace:
```

**Solutions:**
```bash
# Set namespace in kustomization.yaml
kustomize edit set namespace your-namespace

# Or patch individual resources
patches:
- patch: |
    metadata:
      namespace: your-namespace
  target:
    kind: Deployment
    name: your-app
```

### 12. Name Prefix/Suffix Not Applied

**Symptoms:**
```bash
# Resources don't have expected name prefix/suffix
```

**Diagnosis:**
```bash
# Check prefix/suffix settings
yq eval '.namePrefix, .nameSuffix' kustomization.yaml

# Compare expected vs actual names
kustomize build . | grep "name:" | head -10
```

**Solutions:**
```bash
# Set name transformations
kustomize edit set nameprefix dev-
kustomize edit set namesuffix -v1

# Check for conflicting transformations
yq eval '.namePrefix, .nameSuffix' kustomization.yaml
```

## Image Management Issues

### 13. Image Not Updated

**Symptoms:**
```bash
# Image tag/name doesn't change despite kustomize edit set image
```

**Diagnosis:**
```bash
# Check image settings
yq eval '.images' kustomization.yaml

# Check deployment image
kustomize build . | yq eval 'select(.kind == "Deployment") | .spec.template.spec.containers[].image' -

# Verify image name matches exactly
grep -r "image:" base/ overlays/
```

**Solutions:**
```bash
# Ensure exact image name match
kustomize edit set image nginx=nginx:1.21  # 'nginx' must match exactly

# Use newName for registry changes
kustomize edit set image nginx=myregistry.com/nginx:1.21

# Check for multiple image references
grep -r "nginx" base/ overlays/ --include="*.yaml"
```

### 14. Image Digest Not Working

**Symptoms:**
```bash
# Digest-based image references fail
```

**Solutions:**
```bash
# Use digest format correctly
kustomize edit set image app=myregistry.com/app@sha256:abcdef123456...

# Don't mix tag and digest
# Wrong: app=myregistry.com/app:v1.0@sha256:...
# Right: app=myregistry.com/app@sha256:...
```

## Validation and Kubernetes API Issues

### 15. "server-side apply failed"

**Symptoms:**
```bash
$ kubectl apply -k .
error validating data: ValidationError(Deployment.spec.template.spec.containers[0].resources.requests): invalid value: "invalid", must be a valid resource quantity
```

**Cause:** Generated YAML doesn't conform to Kubernetes API schema.

**Diagnosis:**
```bash
# Validate against client-side
kubectl apply -k . --dry-run=client

# Validate against server
kubectl apply -k . --dry-run=server

# Check specific resource format
kustomize build . | kubectl apply --dry-run=server -f -
```

**Solutions:**
```bash
# Fix resource format
resources:
  requests:
    memory: "128Mi"  # Use proper units
    cpu: "100m"      # Use proper format

# Validate YAML syntax
kustomize build . | yq eval . -
```

### 16. "field is immutable"

**Symptoms:**
```bash
$ kubectl apply -k .
error: field is immutable
```

**Cause:** Trying to modify immutable fields on existing resources.

**Solutions:**
```bash
# Delete and recreate resource
kubectl delete -k . && kubectl apply -k .

# Use replace instead of apply
kustomize build . | kubectl replace -f -

# For specific immutable fields, check Kubernetes documentation
```

## Performance Issues

### 17. Slow Build Times

**Symptoms:**
```bash
# kustomize build takes very long time
```

**Diagnosis:**
```bash
# Time the build process
time kustomize build .

# Check for remote resources
grep -r "http" . --include="*.yaml"

# Check directory structure complexity
find . -name "kustomization.yaml" | wc -l
```

**Solutions:**
```bash
# Localize remote resources
kustomize localize target-dir source-dir

# Optimize directory structure
# Avoid deep nesting, use components for shared resources

# Cache remote resources
export KUSTOMIZE_NETWORK_TIMEOUT=30s
```

### 18. Large Output Size

**Symptoms:**
```bash
# Generated YAML is extremely large
```

**Solutions:**
```bash
# Split large kustomizations
# Use components for reusable parts
# Remove unnecessary resources

# Check output size
kustomize build . | wc -l
kustomize build . | wc -c
```

## Testing and Debugging Strategies

### Debug Build Process

```bash
# Enable verbose output
kustomize build . --enable-alpha-plugins --load_restrictor=none

# Show only specific resource types
kustomize build . | yq eval 'select(.kind == "Deployment")' -

# Compare outputs
diff <(kustomize build base) <(kustomize build overlay)

# Validate step by step
kustomize build base | kubectl apply --dry-run=client -f -
kustomize build overlay | kubectl apply --dry-run=client -f -
```

### Validation Scripts

```bash
#!/bin/bash
# validate-kustomize.sh

set -e

echo "Validating Kustomize configurations..."

# Check if kustomization.yaml exists
if [[ ! -f "kustomization.yaml" ]]; then
    echo "❌ No kustomization.yaml found"
    exit 1
fi

# Validate build
if ! kustomize build . > /dev/null; then
    echo "❌ Build failed"
    exit 1
fi

# Validate against Kubernetes API
if ! kustomize build . | kubectl apply --dry-run=client -f - > /dev/null; then
    echo "❌ Kubernetes validation failed"
    exit 1
fi

echo "✅ All validations passed"
```

### Resource Verification

```bash
#!/bin/bash
# verify-resources.sh

EXPECTED_RESOURCES=("Deployment" "Service" "ConfigMap")
BUILT_RESOURCES=$(kustomize build . | yq eval '.kind' - | sort | uniq)

for resource in "${EXPECTED_RESOURCES[@]}"; do
    if echo "$BUILT_RESOURCES" | grep -q "$resource"; then
        echo "✅ $resource found"
    else
        echo "❌ $resource missing"
    fi
done
```

## Environment-Specific Troubleshooting

### Development Environment

```bash
# Common development issues
kubectl get pods -n dev-namespace
kubectl logs -f deployment/dev-myapp
kubectl describe pod <pod-name>

# Check resource quotas
kubectl describe quota -n dev-namespace

# Verify service connectivity
kubectl port-forward service/dev-myapp 8080:80
curl http://localhost:8080/health
```

### Production Environment

```bash
# Production-specific checks
kubectl get pods -n prod-namespace -o wide
kubectl top pods -n prod-namespace
kubectl get hpa -n prod-namespace

# Check resource usage
kubectl describe nodes
kubectl get resourcequota -n prod-namespace

# Verify security policies
kubectl get networkpolicy -n prod-namespace
kubectl get psp  # Pod Security Policies
```

## Preventive Measures

### Pre-commit Hooks

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Validate all kustomization files
find . -name "kustomization.yaml" -exec dirname {} \; | while read dir; do
    echo "Validating $dir"
    (cd "$dir" && kustomize build . > /dev/null) || exit 1
done

echo "All kustomizations valid"
```

### CI/CD Validation

```yaml
# .github/workflows/validate.yml
name: Validate Kustomize
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Install kustomize
      run: |
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/
    - name: Validate configurations
      run: |
        for overlay in overlays/*/; do
          echo "Validating $overlay"
          kustomize build "$overlay" > /dev/null
        done
```

### Monitoring and Alerts

```yaml
# Alert for failed deployments
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: kustomize-deployment-alerts
spec:
  groups:
  - name: kustomize.rules
    rules:
    - alert: DeploymentFailed
      expr: kube_deployment_status_replicas_unavailable > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Deployment has unavailable replicas"
        description: "{{ $labels.deployment }} has {{ $value }} unavailable replicas"
```

This troubleshooting guide covers the most common issues you'll encounter when working with Kustomize. Remember to always validate your configurations before applying them to production environments.