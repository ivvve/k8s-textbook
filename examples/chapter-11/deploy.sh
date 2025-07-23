#!/bin/bash

echo "Deploying Todo Application to Kubernetes..."

# Enable ingress if not already enabled
echo "Enabling ingress..."
minikube addons enable ingress

# Deploy in order
echo "Deploying database layer..."
kubectl apply -f mysql-deployment.yaml

echo "Deploying cache layer..."
kubectl apply -f redis-deployment.yaml

echo "Waiting for database to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/mysql

echo "Initializing database..."
kubectl apply -f db-init-job.yaml
kubectl wait --for=condition=complete --timeout=300s job/db-init

echo "Deploying backend API..."
kubectl apply -f backend-deployment.yaml

echo "Waiting for backend to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/backend

echo "Deploying frontend..."
kubectl apply -f frontend-deployment.yaml

echo "Waiting for frontend to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/frontend

echo "Deploying ingress..."
kubectl apply -f ingress.yaml

echo "Adding todoapp.local to /etc/hosts..."
echo "$(minikube ip) todoapp.local" | sudo tee -a /etc/hosts

echo "Deployment completed!"
echo "Access the application at: http://todoapp.local"
echo ""
echo "To check status:"
echo "kubectl get pods"
echo "kubectl get services"
echo "kubectl get ingress"