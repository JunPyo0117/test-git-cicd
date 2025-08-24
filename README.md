# AWS CI/CD 파이프라인 프로젝트

이 프로젝트는 GitHub Actions를 사용하여 AWS 클라우드에 React 프론트엔드와 NestJS 백엔드를 배포하는 CI/CD 파이프라인을 구현합니다.

## 아키텍처 개요

### CI/CD 파이프라인
- **GitHub** → **GitHub Actions** → **Docker** → **AWS ECR** → **AWS EKS**

### AWS 클라우드 아키텍처
- **Frontend**: React 앱이 S3에 호스팅되고 CloudFront를 통해 CDN 제공
- **Backend**: NestJS 앱이 EKS에서 실행되며 RDS와 연결
- **Load Balancer**: AWS Load Balancer Controller를 통한 ALB 자동 생성
- **DNS**: Route 53을 통한 도메인 관리
- **사용자 접근**: Route 53 → CloudFront → S3 (React) → ALB → EKS (NestJS) → RDS

## 프로젝트 구조

```
├── frontend/                 # React 프론트엔드
├── backend/                  # NestJS 백엔드
├── infrastructure/           # Terraform 인프라 코드
│   ├── main.tf              # 메인 인프라 설정
│   ├── variables.tf         # 변수 정의
│   ├── outputs.tf           # 출력값 정의
│   └── aws-load-balancer-controller-policy.json  # Load Balancer Controller 정책
├── k8s/                     # Kubernetes 매니페스트
│   ├── namespace.yaml       # 네임스페이스
│   ├── backend-deployment.yaml  # 백엔드 배포
│   ├── backend-service.yaml     # 백엔드 서비스
│   ├── ingress.yaml         # ALB Ingress
│   └── aws-load-balancer-controller-sa.yaml  # Load Balancer Controller ServiceAccount
├── scripts/                 # 설치 스크립트 (로컬 개발용)
├── .github/
│   └── workflows/           # GitHub Actions 워크플로우
├── docker-compose.yml       # 로컬 개발용 Docker Compose
└── README.md
```

## 시작하기

### 사전 요구사항
- AWS CLI 설정
- Docker 설치
- Node.js 18+
- kubectl 설치
- Terraform 설치

### 환경 변수 설정
```bash
# AWS 자격 증명
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=ap-northeast-2

# GitHub Secrets 설정 필요
# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY
# AWS_REGION
# ECR_REPOSITORY_NAME
# EKS_CLUSTER_NAME
# S3_BUCKET_NAME
# CLOUDFRONT_DISTRIBUTION_ID
# API_URL (백엔드 API URL)
```

### 배포 순서
1. AWS 인프라 배포 (Terraform)
2. GitHub Secrets 설정
3. 코드 푸시하여 CI/CD 파이프라인 실행
   - 네임스페이스 자동 생성
   - Load Balancer Controller 자동 설치
   - Kubernetes 리소스 자동 배포
   - Docker 이미지 빌드 및 ECR 푸시
   - EKS 자동 배포

### GitHub Actions 워크플로우
- **테스트**: 프론트엔드와 백엔드 의존성 설치 및 테스트
- **빌드 및 푸시**: Docker 이미지 빌드 및 ECR 푸시
- **백엔드 배포**: 
  - 네임스페이스 생성
  - Load Balancer Controller 설치
  - Kubernetes 리소스 배포
- **프론트엔드 배포**: S3 업로드 및 CloudFront 무효화

## 기술 스택

- **Frontend**: React, TypeScript, Vite
- **Backend**: NestJS, TypeScript, TypeORM
- **Database**: PostgreSQL (AWS RDS)
- **Container**: Docker
- **Orchestration**: Kubernetes (AWS EKS)
- **Load Balancer**: AWS Application Load Balancer (ALB)
- **CI/CD**: GitHub Actions
- **Infrastructure**: Terraform
- **CDN**: AWS CloudFront
- **Storage**: AWS S3
- **DNS**: AWS Route 53

## 주요 기능

### 자동화된 인프라 관리
- Terraform을 통한 Infrastructure as Code
- AWS Load Balancer Controller 자동 설치
- EKS 클러스터 자동 구성

### CI/CD 파이프라인
- GitHub Actions를 통한 자동 빌드/배포
- Docker 이미지 자동 빌드 및 ECR 푸시
- EKS 자동 배포
- S3/CloudFront 자동 업데이트

### 로드 밸런싱
- ALB를 통한 트래픽 분산
- Ingress를 통한 라우팅 규칙 관리
- 자동 스케일링 지원

### Health Check
- Kubernetes Liveness/Readiness Probe
- Docker Health Check
- ALB Health Check

## 로컬 개발

### 로컬 환경 실행
```bash
# 전체 스택 실행
docker-compose up -d

# 프론트엔드 접속
open http://localhost:3000

# 백엔드 API 테스트
curl http://localhost:3001/api/messages
curl http://localhost:3001/api/messages/health
```

### 개별 실행
```bash
# Frontend
cd frontend && npm run dev

# Backend
cd backend && npm run start:dev
```

## 최근 수정사항

### 버그 수정
- ✅ Health check 엔드포인트 추가 (`/api/messages/health`)
- ✅ Kubernetes 포트 설정 수정 (3001 포트 일치)
- ✅ Ingress 설정 개선
- ✅ 네임스페이스 자동 생성
- ✅ ALB Target Group 포트 수정
- ✅ Docker health check 스크립트 개선
- ✅ 데이터베이스 SSL 설정 개선

### 보안 개선
- ✅ 프로덕션 환경에서 synchronize 비활성화
- ✅ 환경별 SSL 설정 분리
- ✅ 적절한 리소스 제한 설정

## 트러블슈팅

### 일반적인 문제
1. **Health Check 실패**: `/api/messages/health` 엔드포인트 확인
2. **포트 불일치**: 백엔드는 3001 포트에서 실행
3. **네임스페이스 문제**: `cicd-demo` 네임스페이스가 자동 생성됨
4. **데이터베이스 연결**: RDS SSL 설정 확인
