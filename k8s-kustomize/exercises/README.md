# Kustomize Hands-On Exercises

This directory contains progressive exercises designed to reinforce the concepts learned in each chapter. Each exercise builds upon previous knowledge and provides practical experience with Kustomize.

## Exercise Structure

Each exercise follows this structure:
- **Objective**: What you'll learn and accomplish
- **Prerequisites**: Required knowledge and setup
- **Instructions**: Step-by-step guidance
- **Expected Results**: What success looks like
- **Verification**: How to confirm your solution works
- **Extension Challenges**: Optional advanced tasks
- **Solutions**: Reference implementations

## Exercise Progression

### Beginner Level (Chapters 1-4)

**Exercise 1.1: Environment Setup and Verification**
- Set up Kustomize and minikube
- Verify all tools are working correctly
- Create your first kustomization.yaml

**Exercise 2.1: Creating Your First Kustomization**
- Build a basic web application
- Apply base configuration to minikube
- Understand generated resources

**Exercise 3.1: Understanding Directory Structure**
- Organize resources into proper directories
- Create reusable base configurations
- Implement naming conventions

**Exercise 4.1: Building and Applying Base Configuration**
- Deploy a multi-component application
- Test application functionality
- Debug common deployment issues

### Intermediate Level (Chapters 5-8)

**Exercise 5.1: Creating Environment Overlays**
- Build development, staging, and production overlays
- Implement environment-specific customizations
- Practice environment promotion workflows

**Exercise 5.2: Environment Promotion Workflow**
- Set up automated promotion pipeline
- Validate configurations across environments
- Handle environment-specific secrets

**Exercise 6.1: Strategic Merge Patching**
- Apply complex patches to deployments
- Modify services and ConfigMaps
- Handle array merging scenarios

**Exercise 7.1: JSON Patch Operations**
- Implement precise JSON patches
- Target specific array elements
- Combine JSON and strategic merge patches

**Exercise 8.1: ConfigMap and Secret Generation**
- Generate configurations from files and literals
- Implement environment-specific configurations
- Handle secret rotation and security

### Advanced Level (Chapters 9-12)

**Exercise 9.1: Building Reusable Components**
- Create shared components for monitoring, security, and database
- Compose applications from multiple components
- Share components across teams

**Exercise 10.1: Advanced Feature Integration**
- Implement variable substitution
- Integrate with external tools
- Use custom transformers

**Exercise 11.1: CI/CD Pipeline Setup**
- Set up GitOps workflow with ArgoCD
- Implement automated testing and validation
- Create promotion pipelines

**Exercise 12.1: Production Deployment Strategy**
- Implement comprehensive security policies
- Set up monitoring and observability
- Plan disaster recovery procedures

## Prerequisites

Before starting the exercises, ensure you have:

### Required Tools
- **Kustomize**: Latest version installed
- **kubectl**: Version 1.20 or later
- **minikube**: For local Kubernetes cluster
- **Git**: For version control
- **Text Editor**: VS Code recommended with YAML extension

### System Requirements
- **CPU**: 2+ cores
- **Memory**: 4+ GB RAM
- **Storage**: 10+ GB free space
- **OS**: Linux, macOS, or Windows with WSL2

### Knowledge Prerequisites
- Basic Kubernetes concepts (Pods, Deployments, Services)
- YAML syntax familiarity
- Command-line interface usage
- Git version control basics

## Getting Started

1. **Clone the Repository**:
   ```bash
   git clone <repository-url>
   cd k8s-kustomize/exercises
   ```

2. **Verify Prerequisites**:
   ```bash
   ./verify-setup.sh
   ```

3. **Start with Exercise 1.1**:
   ```bash
   cd exercise-1.1
   cat README.md
   ```

## Exercise Navigation

### Quick Links
- [Exercise 1.1: Environment Setup](exercise-1.1/)
- [Exercise 2.1: First Kustomization](exercise-2.1/)
- [Exercise 4.1: Base Configuration](exercise-4.1/)
- [Exercise 5.1: Environment Overlays](exercise-5.1/)
- [Exercise 6.1: Strategic Merge Patches](exercise-6.1/)
- [Exercise 8.1: ConfigMaps and Secrets](exercise-8.1/)

### By Difficulty
- **Beginner**: Exercises 1.1 - 4.1
- **Intermediate**: Exercises 5.1 - 8.1
- **Advanced**: Exercises 9.1 - 12.1

### By Topic
- **Setup and Basics**: 1.1, 2.1, 3.1, 4.1
- **Environment Management**: 5.1, 5.2
- **Patching**: 6.1, 7.1
- **Configuration**: 8.1
- **Advanced Topics**: 9.1, 10.1, 11.1, 12.1

## Completion Tracking

Track your progress using the checklist:

### Beginner Level
- [ ] Exercise 1.1: Environment Setup and Verification
- [ ] Exercise 2.1: Creating Your First Kustomization
- [ ] Exercise 3.1: Understanding Directory Structure
- [ ] Exercise 4.1: Building and Applying Base Configuration

### Intermediate Level
- [ ] Exercise 5.1: Creating Environment Overlays
- [ ] Exercise 5.2: Environment Promotion Workflow
- [ ] Exercise 6.1: Strategic Merge Patching
- [ ] Exercise 7.1: JSON Patch Operations
- [ ] Exercise 8.1: ConfigMap and Secret Generation

### Advanced Level
- [ ] Exercise 9.1: Building Reusable Components
- [ ] Exercise 10.1: Advanced Feature Integration
- [ ] Exercise 11.1: CI/CD Pipeline Setup
- [ ] Exercise 12.1: Production Deployment Strategy

## Help and Support

### Getting Help
1. **Read the Instructions**: Each exercise has detailed step-by-step instructions
2. **Check Prerequisites**: Ensure all required tools are installed and working
3. **Verify Setup**: Run verification scripts before starting
4. **Review Examples**: Study the provided examples in the `/examples` directory
5. **Check Solutions**: Reference solutions are provided for each exercise

### Common Issues
- **minikube not starting**: Check system resources and Docker availability
- **kubectl connection errors**: Verify minikube is running and context is set
- **Permission errors**: Ensure proper file permissions and user access
- **Network issues**: Check firewall settings and proxy configuration

### Troubleshooting Resources
- [Appendix B: Troubleshooting Guide](../appendices/b-troubleshooting.md)
- [Appendix A: CLI Reference](../appendices/a-cli-reference.md)
- Exercise-specific troubleshooting sections

## Contributing

Help improve these exercises:

1. **Report Issues**: Found a bug or unclear instruction? Open an issue
2. **Suggest Improvements**: Have ideas for better exercises? Submit suggestions
3. **Share Solutions**: Contribute alternative solutions or improvements
4. **Add Examples**: Provide additional real-world examples

### Exercise Guidelines
When contributing exercises:
- Follow the established structure and format
- Include clear objectives and prerequisites
- Provide step-by-step instructions
- Include verification steps
- Add extension challenges for advanced learners
- Test thoroughly before submission

## Additional Resources

### Documentation
- [Official Kustomize Documentation](https://kustomize.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Reference](https://kubernetes.io/docs/reference/kubectl/)

### Community
- [Kustomize GitHub Repository](https://github.com/kubernetes-sigs/kustomize)
- [Kubernetes Slack #kustomize](https://kubernetes.slack.com/channels/kustomize)
- [Stack Overflow Kustomize Questions](https://stackoverflow.com/questions/tagged/kustomize)

### Related Tools
- [ArgoCD](https://argoproj.github.io/argo-cd/) - GitOps deployment tool
- [Helm](https://helm.sh/) - Package manager for Kubernetes
- [Skaffold](https://skaffold.dev/) - Local development workflow tool

---

**Ready to begin?** Start with [Exercise 1.1: Environment Setup and Verification](exercise-1.1/)

**Need help?** Check the [Troubleshooting Guide](../appendices/b-troubleshooting.md) or review the chapter content.