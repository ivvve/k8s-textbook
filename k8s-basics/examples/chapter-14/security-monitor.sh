#!/bin/bash

echo "=== Kubernetes Security Monitoring ==="
echo "Timestamp: $(date)"
echo

# Check for privileged pods
echo "Privileged Pods:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[?(@.spec.securityContext.privileged==true)]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}'

echo -e "\nPods running as root:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[?(@.spec.securityContext.runAsUser==0)]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}'

echo -e "\nPods with host network:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[?(@.spec.hostNetwork==true)]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}'

echo -e "\nPods with host PID:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[?(@.spec.hostPID==true)]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}'

echo -e "\nPods with excessive capabilities:"
kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[]?.securityContext?.capabilities?.add[]? == "SYS_ADMIN" or .spec.containers[]?.securityContext?.capabilities?.add[]? == "NET_ADMIN") | "\(.metadata.namespace)\t\(.metadata.name)"'

echo -e "\nServices with external IPs:"
kubectl get services --all-namespaces -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.loadBalancer.ingress[0].ip}{"\n"}{end}'

echo -e "\nRecent security events:"
kubectl get events --all-namespaces --field-selector type=Warning | grep -i -E "(failed|error|security|denied|forbidden)" | tail -10