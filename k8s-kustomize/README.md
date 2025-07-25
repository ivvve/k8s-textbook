# Kubernetes Kustomize Textbook

A comprehensive, hands-on guide to learning Kustomize for Kubernetes configuration management. This textbook features practical examples with minikube and visual content with Mermaid diagrams.

## 📚 Table of Contents

### Core Chapters

1. **[Introduction to Kustomize](chapters/01-introduction.md)**
   - What is Kustomize and why use it
   - Kustomize vs Helm comparison
   - Configuration management challenges
   - When to use Kustomize
   - Real-world use cases

2. **[Setup and Environment](chapters/02-setup.md)**
   - Installing Kustomize
   - Setting up minikube
   - Verifying installation
   - IDE setup and plugins
   - Basic kubectl integration

3. **[Basic Concepts and Architecture](chapters/03-basic-concepts.md)**
   - Understanding the base/overlay pattern
   - Kustomization.yaml structure
   - Resources, generators, transformers
   - Directory structure conventions
   - Mermaid diagrams showing relationships

4. **[Your First Kustomization](chapters/04-first-kustomization.md)**
   - Creating a base configuration
   - Simple web application example
   - Building and applying configurations
   - Understanding generated resources
   - Hands-on with minikube deployment

5. **[Overlays and Environments](chapters/05-overlays-environments.md)**
   - Creating staging/production overlays
   - Environment-specific customizations
   - Name prefixes and suffixes
   - Namespace management
   - Replica scaling per environment

6. **[Strategic Merge Patches](chapters/06-patches-strategic-merge.md)**
   - Understanding strategic merge
   - Patching deployments, services, configmaps
   - Adding/modifying/removing fields
   - Practical examples with nginx app
   - Complex patch scenarios

7. **[JSON Patches (RFC 6902)](chapters/07-json-patches.md)**
   - When to use JSON patches vs strategic merge
   - JSON patch operations (add, remove, replace, etc.)
   - Targeting specific array elements
   - Advanced patching scenarios
   - Troubleshooting patch issues

8. **[ConfigMaps and Secrets Generation](chapters/08-configmaps-secrets.md)**
   - ConfigMap generators
   - Secret generators
   - File-based vs literal generators
   - Environment-specific configurations
   - Secure secret management practices

9. **[Components and Reusability](chapters/09-components-reusability.md)**
   - Understanding Kustomize components
   - Creating reusable components
   - Sharing configurations across teams
   - Component composition patterns
   - Database, monitoring, logging components

10. **[Advanced Features](chapters/10-advanced-features.md)**
    - Variable substitution
    - Helm chart integration
    - Custom transformers
    - Plugin system
    - Remote resources

11. **[CI/CD Integration](chapters/11-cicd-integration.md)**
    - GitOps workflows with Kustomize
    - ArgoCD integration
    - GitHub Actions examples
    - Automated testing strategies
    - Promotion pipelines

12. **[Best Practices and Production](chapters/12-best-practices.md)**
    - Project organization patterns
    - Security considerations
    - Performance optimization
    - Monitoring and observability
    - Migration strategies

## 🛠️ Practical Examples

Each chapter includes working examples that you can run with minikube:

### Simple Applications
- **nginx Web Server**: Base configuration with staging/production overlays
- **Static Website**: Using ConfigMaps for content management
- **Multi-Environment Deployment**: Showcasing environment-specific configurations

### Multi-Tier Applications
- **Web App + Database**: Complete application stack with Kustomize
- **Microservices Architecture**: Managing multiple interconnected services
- **Monitoring Stack**: Prometheus, Grafana, and application monitoring

### Complex Scenarios
- **E-commerce Platform**: Real-world application with multiple components
- **CI/CD Pipeline Integration**: Automated deployment workflows
- **GitOps Workflow**: Complete GitOps implementation with ArgoCD

## 🎯 Hands-On Exercises

Progressive exercises building from basic to advanced concepts:

### Beginner Level
- **Exercise 1.1**: Environment Setup and Verification
- **Exercise 2.1**: Creating Your First Kustomization
- **Exercise 3.1**: Understanding Directory Structure
- **Exercise 4.1**: Building and Applying Base Configuration

### Intermediate Level
- **Exercise 5.1**: Creating Environment Overlays
- **Exercise 5.2**: Environment Promotion Workflow
- **Exercise 6.1**: Strategic Merge Patching
- **Exercise 7.1**: JSON Patch Operations

### Advanced Level
- **Exercise 8.1**: ConfigMap and Secret Generation
- **Exercise 9.1**: Building Reusable Components
- **Exercise 10.1**: Advanced Feature Integration
- **Exercise 11.1**: CI/CD Pipeline Setup
- **Exercise 12.1**: Production Deployment Strategy

## 📊 Visual Learning

This textbook includes comprehensive Mermaid diagrams for visual learners:

### Architecture Diagrams
- Base/overlay relationship visualization
- Directory structure and file organization
- Patch application flow and precedence
- Component composition and dependencies

### Workflow Diagrams
- Development and deployment workflows
- CI/CD pipeline integration
- GitOps deployment processes
- Environment promotion strategies

### Comparison Charts
- Kustomize vs Helm feature comparison
- Strategic merge vs JSON patch usage
- Different patching strategies and use cases

## 🚀 Getting Started

### Prerequisites
- Basic Kubernetes knowledge (see [k8s-basics](../k8s-basics/))
- Docker installed on your system
- minikube for local testing

### Quick Setup
```bash
# Install Kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash

# Start minikube
minikube start

# Verify installation
kustomize version
kubectl version --client
```

### Running Examples
Each chapter's examples can be found in the `examples/` directory:

```bash
# Navigate to a chapter's examples
cd examples/chapter-04/

# Build the kustomization
kustomize build base/

# Apply to minikube
kustomize build overlays/staging/ | kubectl apply -f -
```

## 📖 Learning Path

### For Beginners
1. Start with [Chapter 1: Introduction](chapters/01-introduction.md)
2. Complete the [Environment Setup](chapters/02-setup.md)
3. Work through [Basic Concepts](chapters/03-basic-concepts.md)
4. Practice with [Your First Kustomization](chapters/04-first-kustomization.md)

### For Intermediate Users
- Focus on [Overlays and Environments](chapters/05-overlays-environments.md)
- Master [Strategic Merge Patches](chapters/06-patches-strategic-merge.md)
- Explore [JSON Patches](chapters/07-json-patches.md)

### For Advanced Users
- Dive into [Components and Reusability](chapters/09-components-reusability.md)
- Implement [CI/CD Integration](chapters/11-cicd-integration.md)
- Follow [Best Practices](chapters/12-best-practices.md)

## 🔗 Integration with Other Textbooks

This textbook builds upon concepts from:
- **[k8s-basics](../k8s-basics/)**: Core Kubernetes concepts and resources
- **[k8s-helm](../k8s-helm/)**: Package management and templating comparison

Cross-references and comparisons are provided throughout to help you understand when to use each tool.

## 📋 Appendices

### Reference Materials
- **[CLI Reference](appendices/a-cli-reference.md)**: Complete Kustomize command reference
- **[Troubleshooting Guide](appendices/b-troubleshooting.md)**: Common issues and solutions
- **[Migration from Helm](appendices/c-migration-from-helm.md)**: Converting Helm charts to Kustomize
- **[Integration Patterns](appendices/d-integration-patterns.md)**: Working with other tools

### Additional Resources
- Glossary of terms and concepts
- External links and references
- Template files and boilerplates
- Command cheat sheets

## 🎯 Learning Objectives

By completing this textbook, you will be able to:

1. **Understand Kustomize fundamentals** and when to use it over other tools
2. **Create and manage** base configurations and environment overlays
3. **Apply patches effectively** using both strategic merge and JSON patch techniques
4. **Generate ConfigMaps and Secrets** dynamically for different environments
5. **Build reusable components** that can be shared across projects and teams
6. **Integrate Kustomize** into CI/CD pipelines and GitOps workflows
7. **Follow best practices** for production deployments and security
8. **Troubleshoot common issues** and optimize configurations for performance

## 🤝 Contributing

This textbook is designed to be a living document. If you find errors, have suggestions for improvements, or want to contribute additional examples:

1. Create issues for bugs or suggestions
2. Submit pull requests for improvements
3. Share your real-world use cases and examples

## 📄 License

This textbook is open source and available for educational use. See the LICENSE file for details.

---

**Next**: Start your journey with [Chapter 1: Introduction to Kustomize](chapters/01-introduction.md)

**Quick Links**: [Setup Guide](chapters/02-setup.md) | [Examples](examples/) | [Exercises](exercises/) | [Troubleshooting](appendices/b-troubleshooting.md)