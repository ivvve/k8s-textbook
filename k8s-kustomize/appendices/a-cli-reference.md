# Appendix A: CLI Reference

## Complete Kustomize Command Reference

This appendix provides a comprehensive reference for all Kustomize commands, options, and usage patterns.

## Core Commands

### `kustomize build`

Build and output the customized resources.

**Syntax:**
```bash
kustomize build [directory] [flags]
```

**Examples:**
```bash
# Build from current directory
kustomize build .

# Build from specific directory
kustomize build overlays/production

# Build and save to file
kustomize build overlays/production > production.yaml

# Build with specific API version
kustomize build --api-version=apps/v1 .
```

**Flags:**
```
--api-version string          API version for resources
--enable-alpha-plugins        Enable alpha plugins
--enable-exec                 Enable exec functions
--enable-helm                 Enable Helm chart support
--env string                  Environment variable format
--helm-command string         Helm command path
--load_restrictor LoadRestrictor  Security restrictions on loading files
--mount stringArray           Mount points for file system access
--network                     Enable network access for remote resources
--network-timeout duration    Network timeout (default 27s)
--reorder string              Reorder resources
-o, --output string           Output format (yaml, json)
```

### `kustomize create`

Create a new kustomization.yaml file.

**Syntax:**
```bash
kustomize create [flags]
```

**Examples:**
```bash
# Create kustomization.yaml in current directory
kustomize create

# Create with specific resources
kustomize create --resources deployment.yaml,service.yaml

# Create with autodetection
kustomize create --autodetect
```

**Flags:**
```
--autodetect                  Auto-detect resources in directory
--namespace string            Set namespace
--resources stringArray       Resources to include
```

### `kustomize edit`

Edit the kustomization.yaml file.

**Syntax:**
```bash
kustomize edit [command] [flags]
```

**Subcommands:**
- `add` - Add resources, patches, or other elements
- `remove` - Remove resources, patches, or other elements
- `set` - Set values like namespace, name prefix, etc.
- `fix` - Fix kustomization.yaml format

## Edit Subcommands

### `kustomize edit add`

Add elements to kustomization.yaml.

**Add Resources:**
```bash
# Add resource files
kustomize edit add resource deployment.yaml
kustomize edit add resource service.yaml configmap.yaml

# Add resource directories
kustomize edit add resource ../base
kustomize edit add resource https://example.com/resource.yaml
```

**Add Patches:**
```bash
# Add strategic merge patches
kustomize edit add patch --path patch.yaml

# Add patches with target
kustomize edit add patch --path patch.yaml --kind Deployment --name myapp

# Add JSON patches
kustomize edit add patch --patch '[{"op": "replace", "path": "/spec/replicas", "value": 3}]' --kind Deployment --name myapp
```

**Add ConfigMap Generators:**
```bash
# From literals
kustomize edit add configmap myconfig --from-literal=key1=value1 --from-literal=key2=value2

# From files
kustomize edit add configmap myconfig --from-file=config.properties

# From environment file
kustomize edit add configmap myconfig --from-env-file=.env
```

**Add Secret Generators:**
```bash
# From literals
kustomize edit add secret mysecret --from-literal=password=secret123

# From files
kustomize edit add secret mysecret --from-file=private.key

# Specify secret type
kustomize edit add secret mysecret --type=kubernetes.io/tls --from-file=tls.crt --from-file=tls.key
```

**Add Components:**
```bash
kustomize edit add component ../components/monitoring
```

**Add Base (Deprecated):**
```bash
kustomize edit add base ../base
```

### `kustomize edit remove`

Remove elements from kustomization.yaml.

```bash
# Remove resources
kustomize edit remove resource deployment.yaml

# Remove patches
kustomize edit remove patch patch.yaml

# Remove configmap generators
kustomize edit remove configmap myconfig

# Remove secret generators
kustomize edit remove secret mysecret
```

### `kustomize edit set`

Set values in kustomization.yaml.

```bash
# Set namespace
kustomize edit set namespace production

# Set name prefix
kustomize edit set nameprefix prod-

# Set name suffix
kustomize edit set namesuffix -v1

# Set image
kustomize edit set image nginx=nginx:1.21
kustomize edit set image app=myregistry/app:v2.0.0

# Set replica count
kustomize edit set replicas deployment/myapp=5
```

## Utility Commands

### `kustomize version`

Display version information.

```bash
kustomize version

# Output format options
kustomize version --short
kustomize version -o json
```

### `kustomize completion`

Generate shell completion scripts.

```bash
# Bash completion
kustomize completion bash > ~/.kustomize-completion.bash
source ~/.kustomize-completion.bash

# Zsh completion
kustomize completion zsh > ~/.kustomize-completion.zsh
source ~/.kustomize-completion.zsh

# Fish completion
kustomize completion fish > ~/.config/fish/completions/kustomize.fish
```

### `kustomize docs-fn`

Generate documentation for functions.

```bash
kustomize docs-fn
```

### `kustomize localize`

Localize remote resources to local files.

```bash
# Download remote resources
kustomize localize target source

# Localize with specific scope
kustomize localize target source --scope subdir
```

## kubectl Integration

Kustomize is built into kubectl since version 1.14.

### `kubectl apply -k`

Apply Kustomize configurations directly.

```bash
# Apply from directory
kubectl apply -k overlays/production

# Apply with dry run
kubectl apply -k overlays/production --dry-run=client

# Apply with server-side dry run
kubectl apply -k overlays/production --dry-run=server
```

### `kubectl diff -k`

Show differences that would be applied.

```bash
kubectl diff -k overlays/production
```

### `kubectl delete -k`

Delete resources defined in kustomization.

```bash
kubectl delete -k overlays/production
```

### `kubectl kustomize`

Build kustomize configuration (same as `kustomize build`).

```bash
kubectl kustomize overlays/production
```

## Environment Variables

### Configuration Variables

```bash
# Enable alpha plugins
export KUSTOMIZE_ENABLE_ALPHA_PLUGINS=true

# Set plugin root directory
export KUSTOMIZE_PLUGIN_HOME=~/.config/kustomize/plugin

# Enable legacy order
export KUSTOMIZE_ENABLE_LEGACY_ORDER=true

# Set function config root
export KUSTOMIZE_FUNCTION_CONFIG_ROOT=./functions
```

### Network Configuration

```bash
# Set network timeout
export KUSTOMIZE_NETWORK_TIMEOUT=60s

# Set HTTP proxy
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080
export NO_PROXY=localhost,127.0.0.1,.local
```

## Command Examples by Use Case

### Basic Operations

```bash
# Initialize new kustomization
mkdir myapp && cd myapp
kustomize create --autodetect

# Add resources
kustomize edit add resource deployment.yaml service.yaml

# Set common configurations
kustomize edit set namespace myapp
kustomize edit set nameprefix prod-
kustomize edit add configmap app-config --from-literal=ENV=production

# Build and validate
kustomize build . | kubectl apply --dry-run=client -f -

# Apply to cluster
kubectl apply -k .
```

### Environment Management

```bash
# Create base configuration
mkdir -p base overlays/{dev,staging,prod}
cd base
kustomize create --resources deployment.yaml,service.yaml

# Create development overlay
cd ../overlays/dev
kustomize create --resources ../../base
kustomize edit set namespace myapp-dev
kustomize edit set nameprefix dev-
kustomize edit set replicas deployment/myapp=1

# Create production overlay
cd ../prod
kustomize create --resources ../../base
kustomize edit set namespace myapp-prod
kustomize edit set nameprefix prod-
kustomize edit set replicas deployment/myapp=5
kustomize edit set image myapp=myapp:v1.0.0
```

### Patch Management

```bash
# Add strategic merge patch
kustomize edit add patch --path increase-replicas.yaml

# Add JSON patch
kustomize edit add patch \
  --patch '[{"op": "replace", "path": "/spec/replicas", "value": 10}]' \
  --kind Deployment \
  --name myapp

# Add patch with specific target
kustomize edit add patch \
  --path resource-limits.yaml \
  --kind Deployment \
  --name myapp \
  --namespace production
```

### Image Management

```bash
# Set image tag
kustomize edit set image nginx=nginx:1.21

# Set image with digest
kustomize edit set image nginx=nginx@sha256:abc123...

# Change image registry
kustomize edit set image nginx=myregistry.com/nginx:1.21

# Multiple images
kustomize edit set image \
  frontend=myregistry.com/frontend:v2.0.0 \
  backend=myregistry.com/backend:v2.0.0
```

### Configuration Generation

```bash
# Generate ConfigMap from file
kustomize edit add configmap app-config \
  --from-file=config.properties \
  --from-file=nginx.conf

# Generate ConfigMap from literals
kustomize edit add configmap env-vars \
  --from-literal=DATABASE_URL=postgres://db:5432/myapp \
  --from-literal=REDIS_URL=redis://redis:6379

# Generate Secret from files
kustomize edit add secret tls-secret \
  --type=kubernetes.io/tls \
  --from-file=tls.crt=server.crt \
  --from-file=tls.key=server.key

# Generate Secret from literals
kustomize edit add secret api-keys \
  --from-literal=stripe=sk_test_... \
  --from-literal=sendgrid=SG....
```

## Advanced Usage Patterns

### Remote Resources

```bash
# Add remote resource
kustomize edit add resource \
  https://raw.githubusercontent.com/user/repo/main/deploy.yaml

# Add Git repository
kustomize edit add resource \
  github.com/user/repo/config?ref=v1.0.0

# Add Helm chart
kustomize edit add resource \
  https://charts.example.com/myapp-1.0.0.tgz
```

### Plugin Usage

```bash
# Enable plugins
export KUSTOMIZE_ENABLE_ALPHA_PLUGINS=true

# Use plugin in kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

generators:
- |-
  apiVersion: myplugin/v1
  kind: MyGenerator
  metadata:
    name: my-generator
  spec:
    value: example
```

### Function Integration

```bash
# Run with function
kustomize fn run --image gcr.io/kustomize-functions/example-fn

# Run function pipeline
kustomize fn run --fn-path functions/

# Source function
kustomize fn source overlays/production | \
  kustomize fn run --image gcr.io/kustomize-functions/set-namespace -- \
  namespace=production | \
  kubectl apply -f -
```

## Troubleshooting Commands

### Validation

```bash
# Validate kustomization syntax
kustomize build . --dry-run

# Validate against Kubernetes API
kustomize build . | kubectl apply --dry-run=server -f -

# Check for common issues
kustomize build . | kubectl apply --dry-run=client -f - --validate=true
```

### Debugging

```bash
# Show detailed build process
kustomize build . --enable-alpha-plugins --load_restrictor=none

# Build with specific output format
kustomize build . -o json | jq .

# Show differences
diff <(kubectl get -o yaml deployment myapp) <(kustomize build . | yq eval 'select(.kind == "Deployment")')
```

### Performance

```bash
# Time the build process
time kustomize build overlays/production

# Build with network timeout
kustomize build . --network-timeout=60s

# Build with specific load restrictor
kustomize build . --load_restrictor=LoadRestrictionsNone
```

## Error Messages and Solutions

### Common Errors

**"unable to find one of 'kustomization.yaml', 'kustomization.yml' or 'Kustomization'"**
```bash
# Solution: Ensure kustomization.yaml exists
ls -la kustomization.yaml
# or create one
kustomize create
```

**"resource not found"**
```bash
# Solution: Check resource paths
kustomize edit remove resource nonexistent.yaml
kustomize edit add resource correct-path.yaml
```

**"plugin not found"**
```bash
# Solution: Enable plugins and check plugin path
export KUSTOMIZE_ENABLE_ALPHA_PLUGINS=true
export KUSTOMIZE_PLUGIN_HOME=~/.config/kustomize/plugin
```

**"patch target not found"**
```bash
# Solution: Verify patch target matches resource
kustomize edit add patch --path patch.yaml --kind Deployment --name correct-name
```

This CLI reference provides comprehensive coverage of all Kustomize commands and usage patterns for effective configuration management.