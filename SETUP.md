# EKS CI/CD 프로젝트 설정 가이드

이 문서는 EKS CI/CD 프로젝트의 상세한 설정 방법을 안내합니다.

## 🏗️ 아키텍처 개요

이 프로젝트는 다음과 같은 AWS 서비스들을 사용합니다:

- **Route 53**: DNS 관리 및 사용자 요청 라우팅
- **CloudFront**: CDN을 통한 콘텐츠 전송 최적화
- **ALB (Application Load Balancer)**: 퍼블릭 서브넷에 위치한 로드 밸런서
- **EKS**: React (프론트엔드) 및 NestJS (백엔드) 컨테이너 실행
- **RDS**: PostgreSQL 데이터베이스
- **ECR**: Docker 이미지 저장소
- **S3**: 프론트엔드 정적 파일 호스팅

## 📋 사전 요구사항

### 필수 도구 설치

1. **AWS CLI 설치**
   ```bash
   # macOS
   brew install awscli
   
   # Linux
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   ```

2. **Terraform 설치**
   ```bash
   # macOS
   brew install terraform
   
   # Linux
   wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update && sudo apt install terraform
   ```

3. **kubectl 설치**
   ```bash
   # macOS
   brew install kubectl
   
   # Linux
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   chmod +x kubectl
   sudo mv kubectl /usr/local/bin/
   ```

4. **Docker 설치**
   ```bash
   # macOS
   brew install --cask docker
   
   # Linux
   sudo apt update
   sudo apt install docker.io
   sudo systemctl start docker
   sudo systemctl enable docker
   sudo usermod -aG docker $USER
   ```

## 🔐 AWS 설정

### 1. AWS 자격 증명 설정

```bash
aws configure
```

다음 정보를 입력하세요:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: `ap-northeast-2`
- Default output format: `json`

### 2. AWS 계정 확인

```bash
aws sts get-caller-identity
```

## 🏗️ 인프라 배포

### 1. Terraform 초기화

```bash
cd infrastructure
terraform init
```

### 2. 배포 계획 확인

```bash
terraform plan
```

### 3. 인프라 배포

```bash
terraform apply
```

배포가 완료되면 다음 출력을 확인하세요:
- `cluster_endpoint`
- `cluster_name`
- `ecr_frontend_repository_url`
- `ecr_backend_repository_url`
- `rds_endpoint`
- `s3_bucket_name`
- `cloudfront_distribution_domain`

## 🔧 GitHub Secrets 설정

GitHub 저장소의 Settings > Secrets and variables > Actions에서 다음 시크릿을 설정하세요:

### 필수 시크릿

1. **AWS_ACCESS_KEY_ID**
   - AWS IAM 사용자의 액세스 키 ID

2. **AWS_SECRET_ACCESS_KEY**
   - AWS IAM 사용자의 시크릿 액세스 키

3. **DB_HOST**
   - RDS 인스턴스 엔드포인트 (terraform output에서 확인)

4. **DB_PASSWORD**
   - RDS 데이터베이스 비밀번호 (terraform output에서 확인)

5. **S3_BUCKET**
   - S3 버킷 이름 (terraform output에서 확인)

6. **CLOUDFRONT_DISTRIBUTION_ID**
   - CloudFront 배포 ID (terraform output에서 확인)

7. **API_URL**
   - 백엔드 API URL (ALB URL, 배포 후 확인)

## 🚀 CI/CD 파이프라인 실행

### 1. 코드 푸시

```bash
git add .
git commit -m "Initial deployment"
git push origin main
```

### 2. GitHub Actions 모니터링

1. GitHub 저장소의 Actions 탭으로 이동
2. 워크플로우 실행 상태 확인
3. 각 단계별 로그 확인

### 3. 배포 확인

GitHub Actions가 완료되면 다음을 확인하세요:

```bash
# EKS 클러스터 접근 설정
aws eks update-kubeconfig --name cicd-cluster --region ap-northeast-2

# Pod 상태 확인
kubectl get pods -n cicd-demo

# Service 상태 확인
kubectl get services -n cicd-demo

# Ingress 상태 확인
kubectl get ingress -n cicd-demo
```

## 🔍 문제 해결

### GitHub Actions EKS 배포 실패

#### 문제: GitHub Actions에서 EKS 배포가 실패함

**해결 방법:**

1. **IAM 역할 권한 확인**
   ```bash
   aws iam get-role --role-name github-actions-role
   aws iam list-attached-role-policies --role-name github-actions-role
   ```

2. **aws-auth ConfigMap 확인**
   ```bash
   kubectl get configmap aws-auth -n kube-system -o yaml
   ```

3. **GitHub Actions 로그 확인**
   - GitHub 저장소의 Actions 탭에서 워크플로우 실행 로그 확인
   - 각 단계별 오류 메시지 확인

4. **OIDC Provider 확인**
   ```bash
   aws iam list-open-id-connect-providers
   ```

#### 문제: aws-auth ConfigMap이 적용되지 않음

**해결 방법:**

1. **테라폼 상태 확인**
   ```bash
   cd infrastructure
   terraform state list | grep aws-auth
   ```

2. **ConfigMap 수동 적용**
   ```bash
   kubectl apply -f aws-auth-configmap.yaml
   ```

3. **테라폼 재실행**
   ```bash
   terraform apply
   ```

### 일반적인 문제들

#### 문제: Pod가 Running 상태가 안됨

**확인 사항:**
```bash
# Pod 상세 정보 확인
kubectl describe pod <pod-name> -n cicd-demo

# Pod 로그 확인
kubectl logs <pod-name> -n cicd-demo

# 이벤트 확인
kubectl get events -n cicd-demo --sort-by='.lastTimestamp'
```

#### 문제: Ingress가 External IP를 받지 못함

**확인 사항:**
```bash
# AWS Load Balancer Controller 확인
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# Ingress 상세 정보 확인
kubectl describe ingress -n cicd-demo

# ALB 확인
aws elbv2 describe-load-balancers
```

#### 문제: 데이터베이스 연결 실패

**확인 사항:**
```bash
# 시크릿 확인
kubectl get secret db-secret -n cicd-demo -o yaml

# 데이터베이스 연결 테스트
kubectl exec -it <pod-name> -n cicd-demo -- nc -zv <db-endpoint> 5432
```

## 🧹 리소스 정리

### 모든 리소스 삭제

```bash
# Kubernetes 리소스 삭제
kubectl delete -f k8s/ --ignore-not-found=true

# 테라폼 리소스 삭제
cd infrastructure
terraform destroy -auto-approve
```

## 📊 모니터링 및 로그

### GitHub Actions 모니터링

- GitHub 저장소의 Actions 탭에서 워크플로우 실행 상태 확인
- 각 단계별 로그 확인
- 실패한 단계의 상세 로그 확인

### AWS 리소스 모니터링

```bash
# EKS 클러스터 상태
aws eks describe-cluster --name cicd-cluster --region ap-northeast-2

# ALB 상태
aws elbv2 describe-load-balancers

# RDS 상태
aws rds describe-db-instances --db-instance-identifier cicd-database
```

### 애플리케이션 상태 확인

```bash
# kubeconfig 설정
aws eks update-kubeconfig --name cicd-cluster --region ap-northeast-2

# Pod 상태
kubectl get pods -n cicd-demo

# Service 상태
kubectl get services -n cicd-demo

# Ingress 상태
kubectl get ingress -n cicd-demo

# 로그 확인
kubectl logs -f deployment/backend -n cicd-demo
```

## 🔄 재배포

### 자동 재배포

코드를 수정하고 푸시하면 GitHub Actions가 자동으로 재배포합니다:

```bash
git add .
git commit -m "Update application"
git push origin main
```

### 수동 재배포

GitHub Actions에서 수동으로 워크플로우를 실행할 수도 있습니다:
1. GitHub 저장소의 Actions 탭으로 이동
2. "CI/CD Pipeline" 워크플로우 선택
3. "Run workflow" 버튼 클릭

## 📝 추가 참고사항

### 환경 변수 설정

```bash
# 프로덕션 환경 변수
export AWS_REGION=ap-northeast-2
export EKS_CLUSTER_NAME=cicd-cluster
export NAMESPACE=cicd-demo
```

### 유용한 명령어

```bash
# 포트 포워딩 (로컬에서 서비스 접근)
kubectl port-forward service/backend 3001:3001 -n cicd-demo

# Pod 내부 접근
kubectl exec -it <pod-name> -n cicd-demo -- /bin/bash

# 설정 확인
kubectl config view
kubectl config current-context
```

### 디버깅 팁

1. **GitHub Actions 로그를 먼저 확인하세요**
2. **kubectl describe 명령어로 상세 정보를 확인하세요**
3. **AWS 콘솔에서 리소스 상태를 확인하세요**
4. **네트워크 연결을 확인하세요**
5. **권한 설정을 확인하세요**
