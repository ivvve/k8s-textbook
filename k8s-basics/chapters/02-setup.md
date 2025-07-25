# Chapter 2: Setting Up Your Environment

## Learning Objectives

By the end of this chapter, you will have:
- Docker installed and running on your system
- minikube installed and configured
- kubectl CLI tool installed and configured
- A working local Kubernetes cluster
- Verified that all components work together

## Prerequisites

- Administrator/sudo access on your machine
- At least 4GB of free RAM
- 10GB of free disk space
- Stable internet connection for downloads

## Step 1: Installing Docker

Docker is required as the container runtime for minikube.

### macOS

#### Option 1: Docker Desktop (Recommended)
1. Download Docker Desktop from [docker.com](https://www.docker.com/products/docker-desktop)
2. Install the downloaded `.dmg` file
3. Start Docker Desktop from Applications
4. Verify installation:
   ```bash
   docker --version
   docker run hello-world
   ```

#### Option 2: Using Homebrew
```bash
brew install --cask docker
```

### Linux (Ubuntu/Debian)

```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add your user to docker group (logout/login required)
sudo usermod -aG docker $USER

# Verify installation
docker --version
docker run hello-world
```

### Windows

1. Download Docker Desktop from [docker.com](https://www.docker.com/products/docker-desktop)
2. Enable WSL2 if prompted
3. Install and restart your system
4. Verify in PowerShell:
   ```powershell
   docker --version
   docker run hello-world
   ```

## Step 2: Installing minikube

minikube creates a local Kubernetes cluster for development and learning.

### macOS

#### Using Homebrew (Recommended)
```bash
brew install minikube
```

#### Manual Installation
```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64
sudo install minikube-darwin-amd64 /usr/local/bin/minikube
```

### Linux

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

### Windows

#### Using Chocolatey
```powershell
choco install minikube
```

#### Manual Installation
1. Download the [Windows installer](https://github.com/kubernetes/minikube/releases/latest)
2. Run the installer as Administrator
3. Add minikube to your PATH

### Verify minikube Installation

```bash
minikube version
```

## Step 3: Installing kubectl

kubectl is the command-line tool for interacting with Kubernetes clusters.

### macOS

#### Using Homebrew
```bash
brew install kubectl
```

#### Manual Installation
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### Linux

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### Windows

#### Using Chocolatey
```powershell
choco install kubernetes-cli
```

#### Manual Installation
1. Download from [Kubernetes releases](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/)
2. Add to your PATH

### Verify kubectl Installation

```bash
kubectl version --client
```

## Step 4: Starting Your First Kubernetes Cluster

Now let's create your first local Kubernetes cluster with minikube.

### Start minikube

```bash
# Start minikube with Docker driver
minikube start --driver=docker

# On some systems, you may need to specify memory
minikube start --driver=docker --memory=4096 --cpus=2
```

This command will:
- Download the Kubernetes ISO
- Create a virtual machine or container
- Configure kubectl to use the minikube cluster
- Start all Kubernetes components

### Expected Output

```
😄  minikube v1.28.0 on Darwin 13.0.1
✨  Using the docker driver based on user configuration
👍  Starting control plane node minikube in cluster minikube
🚜  Pulling base image ...
🔥  Creating docker container (CPUs=2, Memory=4096MB) ...
🐳  Preparing Kubernetes v1.25.3 on Docker 20.10.20 ...
    ▪ Generating certificates and keys ...
    ▪ Booting up control plane ...
    ▪ Configuring RBAC rules ...
🔎  Verifying Kubernetes components...
🌟  Enabled addons: default-storageclass, storage-provisioner
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default
```

## Step 5: Verifying Your Setup

Let's verify that everything is working correctly.

### Check Cluster Status

```bash
# Check minikube status
minikube status

# Check cluster info
kubectl cluster-info

# Check nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system
```

### Expected Outputs

#### minikube status
```
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

#### kubectl cluster-info
```
Kubernetes control plane is running at https://192.168.49.2:8443
CoreDNS is running at https://192.168.49.2:8443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

#### kubectl get nodes
```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   2m    v1.25.3
```

## Step 6: Your First Kubernetes Command

Let's run a simple test to make sure everything works:

```bash
# Create a test deployment
kubectl create deployment hello-minikube --image=k8s.gcr.io/echoserver:1.4

# Check if it's running
kubectl get deployments
kubectl get pods

# Expose it as a service
kubectl expose deployment hello-minikube --type=NodePort --port=8080

# Get the service URL
minikube service hello-minikube --url
```

Visit the URL in your browser to see your first Kubernetes application!

### Clean Up Test Resources

```bash
kubectl delete service hello-minikube
kubectl delete deployment hello-minikube
```

## Useful minikube Commands

```bash
# Stop the cluster
minikube stop

# Start the cluster
minikube start

# Delete the cluster
minikube delete

# Check cluster status
minikube status

# Get minikube IP
minikube ip

# SSH into minikube
minikube ssh

# Open Kubernetes dashboard
minikube dashboard
```

## Troubleshooting Common Issues

### Docker Not Running
**Error**: `Docker is not running`
**Solution**: Start Docker Desktop or Docker daemon

### Insufficient Resources
**Error**: `Exiting due to RSRC_INSUFFICIENT_CORES`
**Solution**: 
```bash
minikube start --cpus=2 --memory=2048
```

### Driver Issues
**Error**: Driver problems
**Solution**: Try different driver:
```bash
minikube start --driver=virtualbox
# or
minikube start --driver=hyperkit
```

### Port Conflicts
**Error**: Port already in use
**Solution**: 
```bash
minikube delete
minikube start
```

## Setting Up kubectl Autocompletion (Optional)

### Bash
```bash
echo 'source <(kubectl completion bash)' >>~/.bashrc
```

### Zsh
```bash
echo 'source <(kubectl completion zsh)' >>~/.zshrc
```

### Fish
```bash
kubectl completion fish | source
```

## What's Next?

Now that you have a working Kubernetes environment, you're ready to:
1. Learn about Pods (Chapter 3)
2. Deploy your first application
3. Explore Kubernetes objects and concepts

## Environment Checklist

Before proceeding to the next chapter, ensure:

- [ ] Docker is installed and running
- [ ] minikube is installed
- [ ] kubectl is installed
- [ ] `minikube start` completes successfully
- [ ] `kubectl get nodes` shows your minikube node as Ready
- [ ] You can create and delete test deployments

## Key Commands Summary

| Command | Purpose |
|---------|---------|
| `docker --version` | Check Docker installation |
| `minikube start` | Start local Kubernetes cluster |
| `minikube status` | Check cluster status |
| `minikube stop` | Stop the cluster |
| `kubectl cluster-info` | Display cluster information |
| `kubectl get nodes` | List cluster nodes |
| `kubectl get pods` | List pods |

---

**Next Chapter**: [Your First Pod](../03-first-pod/) - Learn about Pods and deploy your first containerized application in Kubernetes.