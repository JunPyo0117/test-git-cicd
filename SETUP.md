# AWS CI/CD 파이프라인 설정 가이드

이 문서는 GitHub Actions를 사용한 AWS CI/CD 파이프라인을 설정하는 방법을 설명합니다.

## 1. 사전 요구사항

### 필수 도구 설치 (macOS)
```bash
# Homebrew로 설치
brew install awscli kubectl terraform helm

# Docker Desktop 설치 (https://www.docker.com/products/docker-desktop/)
```

### 필수 도구 설치 (Linux)
```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs)"
sudo apt-get update && sudo apt-get install terraform

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Docker
sudo apt-get update
sudo apt-get install docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

### AWS 계정 설정
```bash
# AWS 자격 증명 설정
aws configure
```

## 2. AWS 인프라 배포

### Terraform 상태 저장용 S3 버킷 생성
```bash
aws s3 mb s3://cicd-terraform-state-471303021447
aws s3api put-bucket-versioning --bucket cicd-terraform-state-471303021447 --versioning-configuration Status=Enabled
```

### 인프라 배포
```bash
cd infrastructure
terraform init
terraform plan
terraform apply
```

### 출력값 저장
배포 완료 후 출력된 값들을 메모해두세요:
- ECR 리포지토리 URL
- EKS 클러스터 이름
- S3 버킷 이름
- CloudFront 배포 ID
- RDS 엔드포인트

## 3. EKS 클러스터 설정

### kubectl 설정
```bash
aws eks update-kubeconfig --name cicd-cluster --region ap-northeast-2
kubectl get nodes  # 클러스터 연결 확인
```

### AWS Load Balancer Controller 설치
```bash
# 스크립트 실행 권한 부여
chmod +x scripts/install-load-balancer-controller.sh

# Load Balancer Controller 설치
./scripts/install-load-balancer-controller.sh

# 설치 상태 확인
kubectl get pods -n kube-system | grep aws-load-balancer-controller
```

### 네임스페이스 및 Kubernetes 리소스 배포
```bash
# 네임스페이스 생성
kubectl apply -f k8s/namespace.yaml

# 백엔드 배포
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml

# Ingress 배포 (ALB 자동 생성)
kubectl apply -f k8s/ingress.yaml

# 배포 상태 확인
kubectl get all -n cicd-demo
kubectl get ingress -n cicd-demo
```

### 데이터베이스 시크릿 생성
```bash
kubectl create secret generic db-secret \
  --from-literal=host=<RDS_ENDPOINT> \
  --from-literal=port=5432 \
  --from-literal=username=postgres \
  --from-literal=password=<DB_PASSWORD> \
  --from-literal=database=cicd_demo \
  -n cicd-demo
```

## 4. GitHub Secrets 설정

GitHub 저장소의 Settings > Secrets and variables > Actions에서 다음 시크릿을 설정하세요:

### 필수 시크릿
- `AWS_ACCESS_KEY_ID`: AWS 액세스 키 ID
- `AWS_SECRET_ACCESS_KEY`: AWS 시크릿 액세스 키
- `AWS_REGION`: AWS 리전 (예: ap-northeast-2)
- `ECR_REPOSITORY_URL`: ECR 리포지토리 URL
- `S3_BUCKET`: S3 버킷 이름
- `CLOUDFRONT_DISTRIBUTION_ID`: CloudFront 배포 ID

### 선택적 시크릿 (도메인이 있는 경우)
- `DOMAIN_NAME`: 도메인 이름

## 5. 로컬 개발 환경

### 의존성 설치
```bash
# Frontend
cd frontend
npm install

# Backend
cd ../backend
npm install
```

### 로컬 실행
```bash
# Docker Compose로 전체 스택 실행
docker-compose up -d

# 프론트엔드 접속
open http://localhost:3000

# 백엔드 API 테스트
curl http://localhost:3001/api/messages

# 또는 개별 실행
# Frontend
cd frontend && npm run dev

# Backend
cd backend && npm run start:dev
```

## 6. CI/CD 파이프라인 테스트

### 코드 푸시
```bash
git add .
git commit -m "Initial commit with Load Balancer Controller"
git push origin main
```

### GitHub Actions 확인
1. GitHub 저장소의 Actions 탭으로 이동
2. 워크플로우 실행 상태 확인
3. 각 단계별 로그 확인

## 7. 배포 확인

### 프론트엔드 확인
- CloudFront URL로 접속
- 메시지 입력/조회 기능 테스트

### 백엔드 확인
```bash
# ALB URL 확인
kubectl get ingress -n cicd-demo

# API 엔드포인트 테스트
curl http://<ALB_URL>/api/messages
```

### Load Balancer Controller 확인
```bash
# Load Balancer Controller 상태 확인
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# ALB 생성 확인
aws elbv2 describe-load-balancers --region ap-northeast-2
```

## 8. 모니터링 및 로그

### EKS 로그 확인
```bash
kubectl logs -f deployment/backend -n cicd-demo
kubectl logs -f deployment/aws-load-balancer-controller -n kube-system
```

### CloudWatch 로그 확인
- AWS 콘솔에서 CloudWatch > Log groups 확인
- EKS 클러스터 로그 확인
- ALB 액세스 로그 확인

## 9. 문제 해결

### 일반적인 문제들

#### ECR 로그인 실패
```bash
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com
```

#### EKS 연결 실패
```bash
aws eks update-kubeconfig --name cicd-cluster --region ap-northeast-2
kubectl get nodes
```

#### Load Balancer Controller 설치 실패
```bash
# Helm repo 업데이트
helm repo update

# 기존 설치 제거 후 재설치
helm uninstall aws-load-balancer-controller -n kube-system
./scripts/install-load-balancer-controller.sh
```

#### RDS 연결 실패
- 보안 그룹 설정 확인
- 서브넷 그룹 설정 확인
- 데이터베이스 엔드포인트 확인

#### Ingress ALB 생성 실패
```bash
# Load Balancer Controller 로그 확인
kubectl logs -f deployment/aws-load-balancer-controller -n kube-system

# IAM 역할 확인
aws iam get-role --role-name aws-load-balancer-controller
```

## 10. 비용 최적화

### 개발 환경용 설정
- EKS 노드 그룹을 Spot 인스턴스로 변경
- RDS 인스턴스를 db.t3.micro로 유지
- CloudFront 캐싱 최적화
- ALB 삭제 (개발 중지 시)

### 프로덕션 환경용 설정
- EKS 노드 그룹을 On-Demand 인스턴스로 변경
- RDS 인스턴스 크기 증가
- Auto Scaling 설정
- ALB 고정 유지

## 11. 보안 고려사항

### 네트워크 보안
- VPC 내 프라이빗 서브넷 사용
- 보안 그룹 최소 권한 원칙 적용
- NAT Gateway 사용
- ALB 보안 그룹 설정

### 애플리케이션 보안
- 환경 변수로 시크릿 관리
- HTTPS 강제 적용
- CORS 설정 최적화
- ALB WAF 연동

### 인프라 보안
- IAM 역할 최소 권한 원칙
- ECR 이미지 스캔 활성화
- CloudTrail 로깅 활성화
- Load Balancer Controller IAM 정책 검토
