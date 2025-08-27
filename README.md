# EKS CI/CD 데모 프로젝트

이 프로젝트는 AWS EKS를 사용한 완전한 CI/CD 파이프라인을 구현한 데모입니다.

## 🏗️ 아키텍처

- **Frontend**: React + Vite + TypeScript + Google Maps
- **Backend**: NestJS + TypeScript
- **Database**: PostgreSQL (RDS)
- **Infrastructure**: Terraform + AWS EKS
- **CI/CD**: GitHub Actions
- **Container Registry**: AWS ECR
- **Load Balancer**: AWS ALB (퍼블릭 서브넷)
- **Load Balancer**: AWS ALB (EKS Ingress Controller가 자동 생성)
- **DNS**: Route 53

## 🔄 아키텍처 흐름

```
사용자 → Route 53 → ALB (퍼블릭) → EKS (React + NestJS) → RDS
                ↓
GitHub → GitHub Actions → Docker → ECR → EKS
```

## 📋 사전 요구사항

- AWS CLI
- Terraform
- kubectl
- Docker
- Node.js 18+
- Google Maps API 키

## 🗺️ Google Maps 설정

### 1. Google Cloud Console에서 API 키 발급

1. [Google Cloud Console](https://console.cloud.google.com/)에 접속
2. 새 프로젝트 생성 또는 기존 프로젝트 선택
3. "API 및 서비스" → "라이브러리"로 이동
4. "Maps JavaScript API" 활성화
5. "사용자 인증 정보" → "사용자 인증 정보 만들기" → "API 키"
6. 발급받은 API 키를 안전하게 보관

### 2. 로컬 개발 환경 설정

프론트엔드 디렉토리에서 환경변수 파일을 생성하세요:

```bash
cd frontend
cp env.example .env.local
```

`.env.local` 파일을 편집하여 API 키를 설정:

```env
# 백엔드 API URL
VITE_API_URL=http://localhost:3000/api

# Google Maps API 키 (필수)
VITE_GOOGLE_MAPS_API_KEY=your_actual_google_maps_api_key_here
```

### 3. API 키 제한 설정 (권장)

보안을 위해 Google Cloud Console에서 API 키에 제한을 설정하세요:

1. **애플리케이션 제한**: HTTP 리퍼러(웹사이트)
   - `localhost:5173/*` (개발 환경)
   - `your-domain.com/*` (프로덕션 환경)

2. **API 제한**: Maps JavaScript API만 선택

### 4. 환경변수 설정 (보안)

⚠️ **중요**: API 키가 Git에 노출되지 않도록 환경변수를 안전하게 설정하세요.

#### 로컬 개발 환경

프로젝트 루트에 `.env` 파일을 생성하세요:

```bash
# .env 파일 생성
cp env.example .env
```

`.env` 파일을 편집하여 실제 API 키를 설정:

```env
# Google Maps API 키 (실제 API 키를 여기에 입력하세요)
GOOGLE_MAPS_API_KEY=your_actual_google_maps_api_key_here

# 백엔드 API URL
VITE_API_URL=http://localhost:3001/api
```

#### Docker 환경

Docker Compose로 실행할 때는 환경변수를 직접 설정하세요:

```bash
# 환경변수와 함께 실행
GOOGLE_MAPS_API_KEY=your_actual_google_maps_api_key_here docker-compose up
```

또는 `.env` 파일을 사용:

```bash
# .env 파일이 있으면 자동으로 로드됨
docker-compose up
```

#### 프로덕션 환경

GitHub Actions에서 시크릿으로 관리됩니다 (아래 참조).

## 🚀 빠른 시작

### 1. 인프라 배포

```bash
cd infrastructure
terraform init
terraform plan
terraform apply
```

### 2. GitHub Secrets 설정

GitHub 저장소의 Settings > Secrets and variables > Actions에서 다음 시크릿을 설정하세요:

#### 필수 시크릿
- `AWS_ACCESS_KEY_ID`: AWS 액세스 키 ID
- `AWS_SECRET_ACCESS_KEY`: AWS 시크릿 액세스 키
- `DB_HOST`: RDS 엔드포인트
- `DB_PASSWORD`: RDS 데이터베이스 비밀번호
- `API_URL`: 백엔드 API URL (ALB URL)
- `GOOGLE_MAPS_API_KEY`: Google Maps API 키

### 3. 로컬 개발 서버 실행

```bash
# 프론트엔드 실행
cd frontend
npm install
npm run dev

# 백엔드 실행 (별도 터미널)
cd backend
npm install
npm run start:dev
```

### 4. 코드 푸시로 자동 배포

```bash
git add .
git commit -m "Add Google Maps integration"
git push origin main
```

GitHub Actions가 자동으로 다음을 수행합니다:
- 프론트엔드/백엔드 테스트
- Docker 이미지 빌드 및 ECR 푸시
- EKS 클러스터에 프론트엔드와 백엔드 배포
- AWS Load Balancer Controller가 ALB 자동 생성

## 🔧 문제 해결

### EKS 클러스터 접근 문제

만약 GitHub Actions에서 EKS 배포가 실패하는 경우:

1. **EKS Access Entry 확인**
   ```bash
   # Access Entry 목록 확인
   aws eks list-access-entries --cluster-name cicd-cluster --region ap-northeast-2
   
   # github-actions-role의 Access Entry 확인
   aws eks describe-access-entry --cluster-name cicd-cluster --principal-arn "arn:aws:iam::471303021447:role/github-actions-role" --region ap-northeast-2
   
   # 연결된 정책 확인
   aws eks list-associated-access-policies --cluster-name cicd-cluster --principal-arn "arn:aws:iam::471303021447:role/github-actions-role" --region ap-northeast-2
   ```

2. **필요한 정책 확인**
   - `AmazonEKSAdminPolicy`
   - `AmazonEKSClusterAdminPolicy`
   
   두 정책이 모두 연결되어 있어야 합니다.

3. **GitHub Actions 로그 확인**
   - GitHub 저장소의 Actions 탭에서 워크플로우 실행 로그 확인

### 일반적인 문제들

- **권한 오류**: GitHub Actions IAM 역할에 적절한 EKS 권한이 부여되었는지 확인
- **네트워크 오류**: VPC와 서브넷 설정 확인
- **인증 오류**: GitHub Secrets 설정 확인

## 📁 프로젝트 구조

```
test-git-cicd/
├── infrastructure/          # Terraform 인프라 코드
│   ├── main.tf             # 메인 테라폼 설정
│   ├── variables.tf        # 변수 정의
│   └── outputs.tf          # 출력 값들
├── k8s/                    # Kubernetes 매니페스트
│   ├── namespace.yaml      # 네임스페이스
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── ingress.yaml
│   └── db-secret.yaml
├── frontend/               # React 프론트엔드
├── backend/                # NestJS 백엔드
├── .github/workflows/      # GitHub Actions 워크플로우
│   └── ci-cd.yml          # CI/CD 파이프라인
└── README.md
```

## 🔐 보안

- GitHub Actions는 OIDC를 통해 AWS에 인증합니다
- EKS 클러스터는 EKS Access Entry를 사용하여 IAM 사용자/역할의 Kubernetes 접근을 관리합니다
- RDS는 프라이빗 서브넷에 배치됩니다
- ECR 리포지토리는 암호화됩니다
- 모든 트래픽은 HTTPS를 통해 전송됩니다

### EKS Access Entry

이 프로젝트는 AWS의 권장 방식인 EKS Access Entry를 사용합니다:

- **my_user**: 로컬 개발용 IAM 사용자
- **github-actions-role**: GitHub Actions CI/CD용 IAM 역할

각각에 다음 정책이 연결됩니다:
- `AmazonEKSAdminPolicy`: 기본 EKS 관리 권한
- `AmazonEKSClusterAdminPolicy`: 클러스터 관리자 권한

기존의 `aws-auth` ConfigMap은 더 이상 사용하지 않습니다.

## 📊 모니터링

### GitHub Actions 모니터링

- GitHub 저장소의 Actions 탭에서 워크플로우 실행 상태 확인
- 각 단계별 로그 확인

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

# Pod 상태 확인
kubectl get pods -n cicd-demo

# Service 상태 확인
kubectl get services -n cicd-demo

# Ingress 상태 확인
kubectl get ingress -n cicd-demo

# 로그 확인
kubectl logs -f deployment/backend -n cicd-demo
```

## 🚨 트러블슈팅

### 자주 발생하는 문제들

1. **GitHub Actions EKS 배포 실패**
   - IAM 역할 권한 확인
   - aws-auth ConfigMap 설정 확인
   - GitHub Secrets 설정 확인

2. **Pod가 Running 상태가 안됨**
   - GitHub Actions 로그에서 이미지 풀 오류 확인
   - 리소스 부족 여부 확인
   - 시크릿 설정 확인

3. **Ingress가 External IP를 받지 못함**
   - AWS Load Balancer Controller 설치 확인
   - IAM 역할 권한 확인

## 📞 지원

문제가 발생하면 다음 순서로 확인해보세요:

1. GitHub Actions 워크플로우 로그 확인
2. AWS CloudWatch 로그 확인
3. kubectl describe 명령어로 상세 정보 확인
4. GitHub Issues에 문제 등록

## 📄 라이선스

MIT License
