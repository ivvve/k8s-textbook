# Chapter 2: Setup and Environment

## Learning Objectives

By the end of this chapter, you will be able to:
- Install Kustomize on your local machine
- Set up and configure minikube for local testing
- Verify all installations are working correctly
- Configure your IDE for optimal Kustomize development
- Understand kubectl integration with Kustomize

## Prerequisites

Before we begin, ensure you have:
- Basic command-line familiarity
- Administrator/sudo access on your machine
- Internet connection for downloading tools
- Basic Kubernetes knowledge (recommended: complete [k8s-basics](../../k8s-basics/))

## Installing Kustomize

Kustomize can be installed in several ways. We'll cover the most common methods for different operating systems.

### Method 1: Standalone Installation (Recommended)

The standalone installation gives you the latest version with all features:

#### macOS
```bash
# Using the official installation script
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash

# Move to a directory in your PATH
sudo mv kustomize /usr/local/bin/

# Or using Homebrew
brew install kustomize
```

#### Linux
```bash
# Download and install
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash

# Move to system path
sudo mv kustomize /usr/local/bin/

# Or using package managers
# Ubuntu/Debian
sudo apt update && sudo apt install kustomize

# CentOS/RHEL/Fedora
sudo dnf install kustomize
```

#### Windows
```powershell
# Using Chocolatey
choco install kustomize

# Using Scoop
scoop install kustomize

# Or download binary from GitHub releases
# https://github.com/kubernetes-sigs/kustomize/releases
```

### Method 2: Built-in kubectl (Limited Features)

Kustomize is built into kubectl since version 1.14:

```bash
# Check if kubectl has kustomize support
kubectl version --client

# Use kubectl kustomize instead of standalone kustomize
kubectl kustomize .
```

**Note**: The built-in version may lag behind the standalone version and might not have all features.

### Verification

Verify your installation:

```bash
# Check Kustomize version
kustomize version

# Expected output similar to:
# {Version:kustomize/v5.0.0 GitCommit:... BuildDate:... GoOs:... GoArch:...}

# Test basic functionality
echo "apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: []" > test-kustomization.yaml

kustomize build .
rm test-kustomization.yaml
```

## Setting Up minikube

minikube provides a local Kubernetes cluster perfect for learning and testing Kustomize configurations.

### Installing minikube

#### macOS
```bash
# Using Homebrew
brew install minikube

# Or using curl
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64
sudo install minikube-darwin-amd64 /usr/local/bin/minikube
```

#### Linux
```bash
# Download and install
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Or using package managers
# Ubuntu/Debian
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
sudo dpkg -i minikube_latest_amd64.deb
```

#### Windows
```powershell
# Using Chocolatey
choco install minikube

# Using Scoop
scoop install minikube

# Or download from GitHub releases
```

### Starting minikube

```bash
# Start minikube with recommended settings
minikube start --driver=docker --memory=4096 --cpus=2

# Verify cluster is running
minikube status

# Expected output:
# minikube
# type: Control Plane
# host: Running
# kubelet: Running
# apiserver: Running
# kubeconfig: Configured
```

### Configure kubectl Context

```bash
# Ensure kubectl is pointing to minikube
kubectl config current-context

# Should show: minikube

# Test cluster connection
kubectl cluster-info

# Create a test namespace
kubectl create namespace kustomize-test
kubectl get namespaces
```

## Installing kubectl

If you don't already have kubectl installed:

### macOS
```bash
# Using Homebrew
brew install kubectl

# Or using curl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### Linux
```bash
# Download latest version
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Or using package managers
sudo apt update && sudo apt install kubectl  # Ubuntu/Debian
sudo dnf install kubectl  # CentOS/RHEL/Fedora
```

### Windows
```powershell
# Using Chocolatey
choco install kubernetes-cli

# Using Scoop
scoop install kubectl
```

## IDE Setup and Plugins

A good development environment makes working with Kustomize much easier.

### Visual Studio Code

Install these recommended extensions:

```bash
# Install VS Code extensions via command line
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
code --install-extension redhat.vscode-yaml
code --install-extension Tim-Koehler.helm-intellisense
```

#### Essential Extensions:
1. **Kubernetes** (ms-kubernetes-tools.vscode-kubernetes-tools)
   - Syntax highlighting for Kubernetes YAML
   - Cluster management
   - Resource navigation

2. **YAML** (redhat.vscode-yaml)
   - Advanced YAML support
   - Schema validation
   - Auto-completion

3. **Helm Intellisense** (Tim-Koehler.helm-intellisense)
   - Also provides Kustomize support
   - Template assistance

#### VS Code Settings

Create `.vscode/settings.json` in your project:

```json
{
  "yaml.schemas": {
    "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/api/kustomization/v1beta1/kustomization_v1beta1.json": [
      "kustomization.yaml",
      "kustomization.yml"
    ]
  },
  "yaml.completion": true,
  "yaml.hover": true,
  "yaml.validate": true,
  "files.associations": {
    "kustomization.yaml": "yaml",
    "kustomization.yml": "yaml"
  }
}
```

### IntelliJ IDEA / GoLand / WebStorm

Install these plugins:
1. **Kubernetes** (JetBrains official)
2. **YAML/Ansible support**

### Vim/Neovim

Add to your `.vimrc` or `init.vim`:

```vim
" YAML support
Plugin 'stephpy/vim-yaml'
Plugin 'pedrohdz/vim-yaml-folds'

" Kubernetes support
Plugin 'andrewstuart/vim-kubernetes'

" Auto-completion
Plugin 'neoclide/coc.nvim'
```

## Directory Structure Setup

Create a workspace for your Kustomize projects:

```bash
# Create main workspace
mkdir -p ~/kustomize-workspace
cd ~/kustomize-workspace

# Create a project structure
mkdir -p my-app/{base,overlays/{development,staging,production}}

# Create example files
cat > my-app/base/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

commonLabels:
  app: my-app
EOF

cat > my-app/base/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: nginx:1.20
        ports:
        - containerPort: 80
EOF

cat > my-app/base/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 80
EOF
```

## Basic kubectl Integration

Understanding how Kustomize integrates with kubectl is crucial:

### Direct Integration

```bash
# Using kubectl with kustomize (built-in)
kubectl kustomize my-app/base/

# Apply directly without separate build step
kubectl apply -k my-app/base/

# Dry run to see what would be applied
kubectl apply -k my-app/base/ --dry-run=client -o yaml
```

### Standalone Usage

```bash
# Using standalone kustomize
kustomize build my-app/base/

# Pipe to kubectl
kustomize build my-app/base/ | kubectl apply -f -

# Save to file
kustomize build my-app/base/ > generated.yaml
kubectl apply -f generated.yaml
```

### Differences Between Methods

| Feature | kubectl kustomize | Standalone kustomize |
|---------|------------------|---------------------|
| Version | Embedded in kubectl | Latest features |
| Performance | Good | Better |
| Features | Basic | Full feature set |
| Updates | With kubectl | Independent |

## Environment Variables and Configuration

Set up helpful environment variables:

```bash
# Add to your shell profile (.bashrc, .zshrc, etc.)
export KUSTOMIZE_WORKSPACE=~/kustomize-workspace
export PATH=$PATH:$HOME/bin

# Useful aliases
alias k=kubectl
alias kc='kubectl kustomize'
alias kb='kustomize build'
alias ka='kubectl apply -k'
alias kd='kubectl delete -k'

# Helper functions
kustomize-build() {
    if [ -f kustomization.yaml ] || [ -f kustomization.yml ]; then
        kustomize build .
    else
        echo "No kustomization.yaml found in current directory"
    fi
}

kustomize-apply() {
    if [ -f kustomization.yaml ] || [ -f kustomization.yml ]; then
        kubectl apply -k .
    else
        echo "No kustomization.yaml found in current directory"
    fi
}
```

## Verification and Testing

Let's verify everything is working correctly:

### 1. Tool Versions
```bash
# Check all tool versions
echo "=== Kustomize ==="
kustomize version

echo "=== kubectl ==="
kubectl version --client

echo "=== minikube ==="
minikube version

echo "=== Docker ==="
docker --version
```

### 2. Cluster Connectivity
```bash
# Test cluster connection
kubectl cluster-info
kubectl get nodes
kubectl get namespaces
```

### 3. Kustomize Functionality
```bash
# Test our example project
cd ~/kustomize-workspace/my-app

# Build base configuration
kustomize build base/

# Apply to cluster
kubectl apply -k base/

# Verify deployment
kubectl get all -l app=my-app

# Clean up
kubectl delete -k base/
```

### 4. IDE Integration Test

1. Open VS Code in your workspace:
   ```bash
   code ~/kustomize-workspace
   ```

2. Open `my-app/base/kustomization.yaml`
3. Verify you get syntax highlighting and auto-completion
4. Try hovering over fields to see documentation

## Troubleshooting Common Issues

### Issue 1: Command Not Found

```bash
# If kustomize command not found
which kustomize
echo $PATH

# Re-run installation or check PATH
```

### Issue 2: minikube Won't Start

```bash
# Check system resources
minikube start --driver=docker --memory=2048 --cpus=1

# Try different driver
minikube start --driver=virtualbox

# Check logs
minikube logs
```

### Issue 3: kubectl Context Issues

```bash
# List available contexts
kubectl config get-contexts

# Switch to minikube
kubectl config use-context minikube

# Verify current context
kubectl config current-context
```

### Issue 4: Permission Errors

```bash
# On Linux/macOS, you might need to fix permissions
sudo chown -R $USER:$USER ~/.kube
sudo chown -R $USER:$USER ~/.minikube
```

## Performance Optimization

### Resource Allocation

For optimal performance during development:

```bash
# Start minikube with appropriate resources
minikube start \
  --driver=docker \
  --memory=4096 \
  --cpus=2 \
  --disk-size=20gb \
  --kubernetes-version=v1.28.0
```

### Docker Settings

If using Docker Desktop:
- Allocate at least 4GB RAM
- Allocate at least 2 CPUs
- Ensure sufficient disk space (20GB+)

## Next Steps

With your environment set up, you're ready to:
1. Understand Kustomize concepts and architecture
2. Create your first kustomization
3. Work with overlays and environments
4. Apply patches and transformations

## Chapter Summary

In this chapter, you've successfully:
- Installed Kustomize, kubectl, and minikube
- Configured your development environment
- Set up IDE support for efficient development
- Created a basic project structure
- Verified all tools are working correctly

Your development environment is now ready for hands-on Kustomize learning!

## Quick Reference

### Essential Commands
```bash
# Start/stop minikube
minikube start
minikube stop

# Kustomize commands
kustomize build <directory>
kubectl apply -k <directory>
kubectl delete -k <directory>

# Check status
kubectl get all
kubectl describe <resource>
kubectl logs <pod>
```

### Useful Aliases
```bash
alias k=kubectl
alias kb='kustomize build'
alias ka='kubectl apply -k'
alias kd='kubectl delete -k'
```

---

**Next**: [Chapter 3: Basic Concepts and Architecture](03-basic-concepts.md)

**Previous**: [Chapter 1: Introduction to Kustomize](01-introduction.md)

**Quick Links**: [Table of Contents](../README.md) | [Examples](../examples/chapter-02/)