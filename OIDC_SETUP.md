# GitHub Actions OIDC 설정 가이드

## 🔍 문제 원인

"Assuming role with OIDC"가 계속 반복되는 문제는 다음 중 하나가 원인입니다:

1. **GitHub Actions OIDC Provider가 AWS에 등록되지 않음**
2. **IAM Role의 Trust Policy가 잘못 설정됨**
3. **GitHub 저장소 정보가 잘못됨**

## 🛠️ 해결 방법

### 1. Terraform으로 OIDC 설정

```bash
# infrastructure 디렉토리로 이동
cd infrastructure

# terraform.tfvars 파일 생성
cat > terraform.tfvars << EOF
github_repository = "your-username/test-git-cicd"  # 실제 GitHub 저장소로 변경
EOF

# Terraform 실행
terraform init
terraform plan
terraform apply
```

### 2. 수동으로 OIDC 설정 (Terraform 없이)

#### 2.1 GitHub Actions OIDC Provider 생성

```bash
# OIDC Provider 생성
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

#### 2.2 IAM Role 생성

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::471303021447:oidc-provider/token.actions.githubusercontent.com"
      },
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:your-username/test-git-cicd:*"
        }
      }
    }
  ]
}
```

#### 2.3 IAM Policy 생성

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:AccessKubernetesApi"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    }
  ]
}
```

### 3. GitHub Secrets에서 Access Key 제거

OIDC가 설정되면 다음 Secrets를 제거할 수 있습니다:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## 🔧 디버깅

### OIDC 토큰 확인

```bash
# GitHub Actions에서 실행
curl -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=sts.amazonaws.com"
```

### IAM Role 확인

```bash
# AWS CLI로 역할 확인
aws iam get-role --role-name github-actions-role
aws iam list-role-policies --role-name github-actions-role
aws iam list-attached-role-policies --role-name github-actions-role
```

## ✅ 확인 사항

1. **GitHub 저장소 이름이 정확한지 확인**
   - `your-username/test-git-cicd` → 실제 저장소 이름으로 변경

2. **OIDC Provider가 생성되었는지 확인**
   ```bash
   aws iam list-open-id-connect-providers
   ```

3. **IAM Role의 Trust Policy가 올바른지 확인**
   - `token.actions.githubusercontent.com:sub` 조건이 정확한 저장소를 가리키는지 확인

4. **IAM Policy가 필요한 권한을 포함하는지 확인**
   - EKS, ECR 권한이 모두 포함되어 있는지 확인

## 🚨 주의사항

- GitHub 저장소 이름은 `owner/repo` 형식이어야 합니다
- OIDC Provider는 AWS 계정당 하나만 생성할 수 있습니다
- IAM Role의 Trust Policy에서 저장소 이름이 정확해야 합니다
