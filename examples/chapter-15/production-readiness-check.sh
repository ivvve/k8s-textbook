#!/bin/bash

# Production Readiness Assessment
echo "=== Kubernetes Production Readiness Check ==="
echo "Assessment Date: $(date)"
echo

SCORE=0
MAX_SCORE=0

check_item() {
  local description="$1"
  local command="$2"
  local weight="$3"
  
  MAX_SCORE=$((MAX_SCORE + weight))
  
  echo -n "Checking: $description... "
  
  if eval "$command" &> /dev/null; then
    echo "✓ PASS"
    SCORE=$((SCORE + weight))
  else
    echo "✗ FAIL"
  fi
}

echo "Infrastructure Checks:"
echo "====================="

check_item "Multiple nodes available" "[ \$(kubectl get nodes --no-headers | wc -l) -gt 1 ]" 10
check_item "All nodes are Ready" "! kubectl get nodes --no-headers | grep -v Ready" 10
check_item "Control plane is HA" "[ \$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers | wc -l) -gt 2 ]" 15
check_item "etcd is external/HA" "kubectl get pods -n kube-system | grep etcd | wc -l | grep -q '[3-9]'" 15

echo -e "\nSecurity Checks:"
echo "==============="

check_item "RBAC is enabled" "kubectl auth can-i '*' '*' --as=system:anonymous | grep -q 'no'" 10
check_item "Pod Security Standards enabled" "kubectl get ns -o json | jq -e '.items[] | select(.metadata.labels[\"pod-security.kubernetes.io/enforce\"])'" 10
check_item "Network policies exist" "[ \$(kubectl get networkpolicies --all-namespaces --no-headers | wc -l) -gt 0 ]" 10
check_item "No privileged pods" "! kubectl get pods --all-namespaces -o json | jq -e '.items[] | select(.spec.securityContext.privileged == true)'" 10

echo -e "\nApplication Checks:"
echo "=================="

check_item "Health checks configured" "kubectl get pods --all-namespaces -o json | jq -e '.items[] | select(.spec.containers[].livenessProbe)'" 10
check_item "Resource limits set" "kubectl get pods --all-namespaces -o json | jq -e '.items[] | select(.spec.containers[].resources.limits)'" 10
check_item "HPA configured" "[ \$(kubectl get hpa --all-namespaces --no-headers | wc -l) -gt 0 ]" 5
check_item "PDB configured" "[ \$(kubectl get pdb --all-namespaces --no-headers | wc -l) -gt 0 ]" 5

echo -e "\nMonitoring Checks:"
echo "================="

check_item "Prometheus installed" "kubectl get pods -n monitoring | grep prometheus" 10
check_item "Grafana installed" "kubectl get pods -n monitoring | grep grafana" 5
check_item "Alert manager configured" "kubectl get pods -n monitoring | grep alertmanager" 10
check_item "Log aggregation setup" "kubectl get pods -n kube-system | grep -E '(fluentd|fluent-bit|filebeat)'" 10

echo -e "\nBackup Checks:"
echo "============="

check_item "Backup solution installed" "kubectl get pods --all-namespaces | grep -E '(velero|ark)'" 15
check_item "Backup schedules configured" "[ \$(kubectl get schedule --all-namespaces --no-headers | wc -l) -gt 0 ]" 10
check_item "etcd backup configured" "systemctl is-active etcd-backup" 15

echo -e "\n=== Assessment Results ==="
echo "Score: $SCORE / $MAX_SCORE"
PERCENTAGE=$((SCORE * 100 / MAX_SCORE))
echo "Percentage: $PERCENTAGE%"

if [ $PERCENTAGE -ge 90 ]; then
  echo "Status: ✓ PRODUCTION READY"
elif [ $PERCENTAGE -ge 70 ]; then
  echo "Status: ⚠ MOSTLY READY (Some improvements needed)"
elif [ $PERCENTAGE -ge 50 ]; then
  echo "Status: ⚠ PARTIALLY READY (Significant improvements needed)"
else
  echo "Status: ✗ NOT PRODUCTION READY (Major issues to address)"
fi

echo -e "\nRecommendations based on failed checks above."