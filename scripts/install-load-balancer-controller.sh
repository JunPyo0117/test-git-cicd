#!/bin/bash

# AWS Load Balancer Controller 설치 스크립트

echo "🚀 AWS Load Balancer Controller 설치 시작..."

# CRDs 설치
echo "📋 CRDs 설치 중..."
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

# Helm repo 추가
echo "📦 Helm repo 추가 중..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Load Balancer Controller 설치
echo "🔧 Load Balancer Controller 설치 중..."
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=cicd-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

echo "✅ AWS Load Balancer Controller 설치 완료!"
echo "📊 설치 상태 확인: kubectl get pods -n kube-system | grep aws-load-balancer-controller"
