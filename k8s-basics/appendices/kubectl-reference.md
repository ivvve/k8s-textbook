# Appendix A: kubectl Command Reference

This reference provides a comprehensive list of commonly used kubectl commands organized by category.

## Basic Commands

### Cluster Information
```bash
kubectl cluster-info                    # Display cluster info
kubectl version                        # Show client and server versions
kubectl config view                    # Show kubeconfig settings
kubectl config current-context         # Display current context
kubectl config get-contexts           # List all contexts
kubectl config use-context <context>   # Switch context
```

### Namespace Operations
```bash
kubectl get namespaces                 # List all namespaces
kubectl create namespace <name>        # Create namespace
kubectl delete namespace <name>        # Delete namespace
kubectl config set-context --current --namespace=<name>  # Set default namespace
```

## Resource Management

### Pods
```bash
kubectl get pods                       # List pods in current namespace
kubectl get pods --all-namespaces     # List pods in all namespaces
kubectl get pods -o wide              # List pods with additional info
kubectl get pods --show-labels        # Show pod labels
kubectl describe pod <name>           # Detailed pod information
kubectl logs <pod-name>               # View pod logs
kubectl logs -f <pod-name>            # Follow pod logs
kubectl logs <pod-name> -c <container> # Logs from specific container
kubectl exec -it <pod-name> -- <command> # Execute command in pod
kubectl delete pod <name>             # Delete pod
kubectl delete pods --all             # Delete all pods
```

### Deployments
```bash
kubectl get deployments               # List deployments
kubectl describe deployment <name>    # Detailed deployment info
kubectl create deployment <name> --image=<image> # Create deployment
kubectl scale deployment <name> --replicas=<count> # Scale deployment
kubectl rollout status deployment <name> # Check rollout status
kubectl rollout history deployment <name> # View rollout history
kubectl rollout undo deployment <name> # Rollback deployment
kubectl delete deployment <name>      # Delete deployment
```

### Services
```bash
kubectl get services                   # List services
kubectl get svc                       # Short form
kubectl describe service <name>       # Detailed service info
kubectl expose deployment <name> --port=<port> # Create service
kubectl delete service <name>         # Delete service
```

### ReplicaSets
```bash
kubectl get replicasets               # List replica sets
kubectl get rs                       # Short form
kubectl describe rs <name>           # Detailed replica set info
kubectl delete rs <name>             # Delete replica set
```

## Configuration and Secrets

### ConfigMaps
```bash
kubectl get configmaps                # List config maps
kubectl get cm                       # Short form
kubectl describe cm <name>           # Detailed config map info
kubectl create cm <name> --from-literal=<key>=<value> # Create from literal
kubectl create cm <name> --from-file=<file> # Create from file
kubectl delete cm <name>             # Delete config map
```

### Secrets
```bash
kubectl get secrets                   # List secrets
kubectl describe secret <name>       # Detailed secret info
kubectl create secret generic <name> --from-literal=<key>=<value> # Create secret
kubectl create secret docker-registry <name> --docker-server=<server> --docker-username=<user> --docker-password=<pass> # Docker registry secret
kubectl delete secret <name>         # Delete secret
```

## Storage

### Persistent Volumes
```bash
kubectl get pv                        # List persistent volumes
kubectl describe pv <name>            # Detailed PV info
kubectl delete pv <name>              # Delete persistent volume
```

### Persistent Volume Claims
```bash
kubectl get pvc                       # List persistent volume claims
kubectl describe pvc <name>           # Detailed PVC info
kubectl delete pvc <name>             # Delete PVC
```

## Networking

### Ingress
```bash
kubectl get ingress                   # List ingress resources
kubectl describe ingress <name>       # Detailed ingress info
kubectl delete ingress <name>         # Delete ingress
```

### Network Policies
```bash
kubectl get networkpolicies           # List network policies
kubectl get netpol                   # Short form
kubectl describe netpol <name>       # Detailed network policy info
```

## Workload Management

### Jobs
```bash
kubectl get jobs                      # List jobs
kubectl describe job <name>          # Detailed job info
kubectl delete job <name>            # Delete job
```

### CronJobs
```bash
kubectl get cronjobs                  # List cron jobs
kubectl get cj                       # Short form
kubectl describe cj <name>           # Detailed cron job info
kubectl delete cj <name>             # Delete cron job
```

### DaemonSets
```bash
kubectl get daemonsets               # List daemon sets
kubectl get ds                      # Short form
kubectl describe ds <name>          # Detailed daemon set info
kubectl delete ds <name>            # Delete daemon set
```

## Resource Creation and Management

### Apply and Create
```bash
kubectl apply -f <file>              # Apply configuration from file
kubectl apply -f <directory>         # Apply all YAML files in directory
kubectl create -f <file>             # Create resource from file
kubectl replace -f <file>            # Replace resource
kubectl delete -f <file>             # Delete resource defined in file
```

### Generate YAML
```bash
kubectl create deployment <name> --image=<image> --dry-run=client -o yaml # Generate deployment YAML
kubectl create service clusterip <name> --tcp=<port> --dry-run=client -o yaml # Generate service YAML
kubectl run <name> --image=<image> --dry-run=client -o yaml # Generate pod YAML
```

## Debugging and Troubleshooting

### Events
```bash
kubectl get events                    # List cluster events
kubectl get events --sort-by=.metadata.creationTimestamp # Sort events by time
kubectl describe <resource> <name>   # Get events for specific resource
```

### Resource Usage
```bash
kubectl top nodes                     # Node resource usage (requires metrics-server)
kubectl top pods                     # Pod resource usage
kubectl top pods --containers        # Container resource usage
```

### Port Forwarding
```bash
kubectl port-forward <pod-name> <local-port>:<pod-port> # Forward port to pod
kubectl port-forward service/<service-name> <local-port>:<service-port> # Forward port to service
```

### Proxy
```bash
kubectl proxy                        # Start proxy to Kubernetes API
kubectl proxy --port=8080           # Start proxy on specific port
```

## Advanced Operations

### Labels and Selectors
```bash
kubectl get pods --selector=<key>=<value> # Get pods by label
kubectl get pods -l <key>=<value>    # Short form
kubectl label pod <name> <key>=<value> # Add label to pod
kubectl label pod <name> <key>-      # Remove label from pod
kubectl get pods --show-labels       # Show all labels
```

### Annotations
```bash
kubectl annotate pod <name> <key>=<value> # Add annotation
kubectl annotate pod <name> <key>-   # Remove annotation
```

### Resource Quotas and Limits
```bash
kubectl get resourcequotas           # List resource quotas
kubectl get limitranges             # List limit ranges
kubectl describe quota <name>       # Detailed quota info
kubectl describe limits <name>      # Detailed limits info
```

## Output Formatting

### Output Options
```bash
kubectl get pods -o wide             # Wide output
kubectl get pods -o yaml            # YAML output
kubectl get pods -o json            # JSON output
kubectl get pods -o name            # Only names
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase # Custom columns
kubectl get pods --no-headers       # No headers
```

### Sorting and Filtering
```bash
kubectl get pods --sort-by=.metadata.name # Sort by name
kubectl get pods --sort-by=.status.startTime # Sort by start time
kubectl get pods --field-selector=status.phase=Running # Field selector
kubectl get pods --field-selector=spec.nodeName=<node-name> # Pods on specific node
```

## Useful Aliases

Add these to your shell profile for faster kubectl usage:

```bash
alias k=kubectl
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kdp='kubectl describe pod'
alias kds='kubectl describe service'
alias kdd='kubectl describe deployment'
alias kl='kubectl logs'
alias ke='kubectl exec -it'
alias kpf='kubectl port-forward'
alias ka='kubectl apply -f'
alias kd='kubectl delete'
```

## Common Patterns

### Watch Resources
```bash
kubectl get pods -w                  # Watch pods for changes
kubectl get events -w               # Watch events
```

### Multiple Resources
```bash
kubectl get pods,services           # Get multiple resource types
kubectl delete pods,services --all  # Delete multiple resource types
```

### Context and Namespace Shortcuts
```bash
kubectl get pods -n <namespace>      # Specify namespace
kubectl get pods --all-namespaces   # All namespaces (-A short form)
```

## Tips and Best Practices

1. **Use aliases** to speed up common operations
2. **Always specify namespace** explicitly when working with multiple namespaces
3. **Use `--dry-run=client`** to test commands before applying
4. **Use labels consistently** for better resource management
5. **Save frequently used commands** as shell scripts or aliases
6. **Use `kubectl explain`** to understand resource specifications
7. **Enable command completion** for your shell

## Command Completion Setup

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