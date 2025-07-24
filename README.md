# Kubernetes for Complete Beginners with Minikube

A comprehensive, hands-on textbook for learning Kubernetes from scratch using minikube. This book is designed for developers, system administrators, and anyone interested in container orchestration who wants to learn Kubernetes through practical examples.

## 📚 What You'll Learn

- Fundamental Kubernetes concepts and architecture
- Setting up a local Kubernetes development environment with minikube
- Deploying and managing applications in Kubernetes
- Configuration management and persistent storage
- Networking, security, and best practices
- Real-world deployment scenarios

## 🎯 Target Audience

- Developers new to Kubernetes
- System administrators exploring container orchestration
- DevOps engineers starting their Kubernetes journey
- Anyone with basic Docker knowledge wanting to learn Kubernetes

## 📋 Prerequisites

- Basic understanding of containers and Docker
- Command line familiarity
- Text editor knowledge
- Basic networking concepts

## 📖 Table of Contents

### Part I: Foundation
- **[Chapter 1: Introduction to Kubernetes](./chapters/01-introduction.md)** - Understanding what Kubernetes is and why we need container orchestration
- **[Chapter 2: Setting Up Your Environment](./chapters/02-setup.md)** - Installing Docker, minikube, and kubectl

### Part II: Core Concepts
- **[Chapter 3: Your First Pod](./chapters/03-first-pod.md)** - Understanding and creating Pods with practical examples
- **[Chapter 4: Services and Networking](./chapters/04-services.md)** - Exposing applications and understanding Kubernetes networking
- **[Chapter 5: Deployments and ReplicaSets](./chapters/05-deployments.md)** - Managing application lifecycle, scaling, and updates

### Part III: Configuration and Storage
- **[Chapter 6: ConfigMaps and Secrets](./chapters/06-config-secrets.md)** - Managing configuration data and sensitive information
- **[Chapter 7: Persistent Volumes and Storage](./chapters/07-storage.md)** - Understanding storage in Kubernetes

### Part IV: Advanced Concepts
- **[Chapter 8: Namespaces and Resource Management](./chapters/08-namespaces.md)** - Organizing resources and managing multi-environment setups
- **[Chapter 9: Ingress and Load Balancing](./chapters/09-ingress.md)** - Advanced networking and traffic routing
- **[Chapter 10: Health Checks and Monitoring](./chapters/10-monitoring.md)** - Ensuring application reliability and observability

### Part V: Real-World Applications
- **[Chapter 11: Multi-Tier Application Deployment](./chapters/11-multi-tier.md)** - Deploying complete application stacks
- **[Chapter 12: CI/CD with Kubernetes](./chapters/12-cicd.md)** - Automated deployment pipelines and GitOps basics

### Part VI: Troubleshooting and Best Practices
- **[Chapter 13: Debugging and Troubleshooting](./chapters/13-debugging.md)** - Common issues, solutions, and debugging techniques
- **[Chapter 14: Security Best Practices](./chapters/14-security.md)** - Kubernetes security fundamentals and RBAC
- **[Chapter 15: Production Readiness](./chapters/15-production.md)** - Moving beyond minikube and production considerations

### Appendices
- **[Appendix A: kubectl Command Reference](./appendices/kubectl-reference.md)**
- **[Appendix B: YAML Templates and Examples](./appendices/yaml-templates.md)**
- **[Appendix C: Troubleshooting Guide](./appendices/troubleshooting.md)**
- **[Appendix D: Additional Resources](./appendices/resources.md)**

## 🚀 Getting Started

1. **Clone this repository:**

2. **Start with Chapter 1:**
   Navigate to `chapters/01-introduction/` and follow the README instructions.

3. **Follow along with examples:**
   Each chapter includes practical examples in the `examples/` directory.

## 📁 Repository Structure

```
k8s-textbook/
├── README.md                    # This file
├── chapters/                    # Individual chapter content
│   ├── 01-introduction/
│   ├── 02-setup/
│   └── ...
├── examples/                    # Practical examples and YAML files
│   ├── chapter-03/
│   ├── chapter-04/
│   └── ...
├── templates/                   # Reusable YAML templates
└── appendices/                  # Reference materials and guides
```

## 🔧 Requirements

- **Docker**: Latest stable version
- **minikube**: v1.25.0 or later
- **kubectl**: Compatible with your minikube Kubernetes version
- **Operating System**: Linux, macOS, or Windows with WSL2

## 💡 How to Use This Book

1. **Sequential Learning**: Follow chapters in order for a complete learning path
2. **Hands-on Practice**: Run all examples in your minikube environment
3. **Experiment**: Modify examples to deepen understanding
4. **Reference**: Use appendices for quick command and concept lookup

## 🙋 Support

- **Issues**: Report problems or ask questions via GitHub Issues
- **Discussions**: Join community discussions in GitHub Discussions
- **Documentation**: All examples are tested with minikube v1.25.0+

## 🏆 Learning Path Recommendations

- **Beginner**: Start with Part I and work through Part III
- **Intermediate**: Focus on Parts IV and V
- **Advanced**: Concentrate on Part VI and real-world scenarios

---

**Happy Learning!** 🎉

Start your Kubernetes journey with confidence using practical, tested examples that work with minikube.