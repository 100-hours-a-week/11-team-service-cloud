# Cloud Infrastructure

> **Version:** v2.0.0

1. 개요
2. Quick Start
3. CI/CD
4. Terraform (IaC) - 인프라 구축
5. 환경 변수

# 1. 개요

## 구조

```
cloud/
├── ci-cd/                   # GitHub Actions (frontend, backend, ai)
├── terraform/
│   ├── envs/                # 환경별 구성 (dev, staging, prod, shared)
│   └── modules/             # 재사용 모듈 (network, compute, iam, rds, ecr, s3, ...)
└── k6-scripts/              # 부하 테스트 (k6)
```

## 아키텍처

```
Client → ALB(:443) → /*      → Web ASG (React :3000)
                   → /api/*  → App Spring ASG (:8080) → RDS (MySQL)
       Internal ALB → /api/* → App Spring ASG (:8080)
                   → /ai/*  → App AI ASG (:8000)
```

- 각 서비스(Web, Spring, AI)는 Docker 컨테이너로 ASG에서 운영
- ECR에서 이미지를 Pull하여 배포
- 환경변수는 AWS Parameter Store에서 관리

# 2. Quick Start

## 사전 요구사항

- [ ] **AWS CLI 설정**: `aws configure`로 credentials 설정
- [ ] **Terraform 설치**: [공식 문서](https://developer.hashicorp.com/terraform/install) 참고
- [ ] **도메인 준비**: ACM 인증서 발급을 위한 도메인 및 DNS 관리 권한

## 시작하기

```bash
# 1. 환경별 Terraform 변수 설정
cd terraform/envs/dev  # 또는 staging, prod
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars

# 2. 인프라 생성
terraform init
terraform plan
terraform apply

# 3. DNS 설정
# 출력된 ALB DNS를 도메인에 CNAME으로 등록
```

배포는 GitHub Actions CI/CD를 통해 자동으로 수행됩니다. `main` 브랜치에 코드가 푸시되면 ECR에 이미지를 빌드하고 ASG를 통해 롤링 배포됩니다.

# 3. CI/CD

GitHub Actions를 사용하여 각 서비스(Frontend, Backend, AI)의 독립적인 자동 배포를 지원합니다.

| 서비스   | CI 워크플로우           | CD 워크플로우           |
| -------- | ----------------------- | ----------------------- |
| Frontend | `ci-cd/frontend/ci.yml` | `ci-cd/frontend/cd.yml` |
| Backend  | `ci-cd/backend/ci.yml`  | `ci-cd/backend/cd.yml`  |
| AI       | `ci-cd/ai/ci.yml`       | `ci-cd/ai/cd.yml`       |

`main` 브랜치에 코드가 푸시되면 해당 서비스의 배포 파이프라인이 자동으로 실행됩니다.

## CI 파이프라인

<div align="center">
<img width="700" alt="ci" src="https://github.com/user-attachments/assets/e58c52fc-7c91-4f29-b449-972e8b1ec8dc" />
</div>

## CD 파이프라인

<div align="center">
<img width="700" alt="c2" src="https://github.com/user-attachments/assets/22a23eea-0bd5-4786-a549-f7343a246389" />
</div>

# 4. Terraform (IaC) - 인프라 구축

AWS 인프라를 코드로 관리합니다. 환경별로 분리된 구조로 리소스를 관리합니다.

### 환경 구조

```
terraform/
├── envs/
│   ├── dev/               # 개발 환경
│   ├── staging/           # 스테이징 환경
│   ├── prod/              # 프로덕션 환경
│   └── shared/            # 공유 리소스
└── modules/               # 재사용 모듈
```

### 모듈 구조

| 모듈                       | 설명                                                            |
| -------------------------- | --------------------------------------------------------------- |
| `modules/network`          | VPC, Subnet, Security Group, Internet Gateway, Route Table, EIP |
| `modules/compute`          | EC2 인스턴스                                                    |
| `modules/iam`              | IAM 역할 및 권한 (Parameter Store, S3, ECR 접근)                |
| `modules/rds`              | RDS (MySQL) 인스턴스                                            |
| `modules/ecr`              | ECR 컨테이너 레지스트리                                         |
| `modules/s3`               | S3 버킷                                                         |
| `modules/ssm-human-access` | SSM 접근 권한                                                   |

### 사용법

```bash
cd terraform/envs/dev  # 환경 선택
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars    # 환경에 맞게 수정

terraform init         # 초기화
terraform plan         # 변경 사항 미리보기
terraform apply        # 인프라 적용
```

### EC2 초기화 과정 (user_data)

ASG Launch Template에 정의된 user_data로 인스턴스 생성 시 자동 실행:

1. Docker 활성화
2. ECR 로그인 및 Docker 이미지 Pull
3. Parameter Store에서 환경변수 가져오기
4. S3에서 docker compose 파일 가져오기 
5. Docker 컨테이너 실행

### DNS 설정 (필수)

`terraform apply` 후 출력되는 ALB DNS를 도메인에 CNAME으로 등록합니다. HTTPS는 ACM 인증서를 ALB에 연결하여 처리합니다.

# 5. 환경 변수

인프라 변수는 각 환경의 `terraform.tfvars`에서 관리합니다. 주요 설정:

| 변수                      | 설명                                 |
| ------------------------- | ------------------------------------ |
| `region`                  | AWS 리전                             |
| `project_name`            | 프로젝트 이름 (리소스 네이밍에 사용) |
| `vpc_cidr`                | VPC CIDR 블록                        |
| `web_instance_type`       | Web 티어 인스턴스 타입               |
| `app_instance_type`       | App 티어 인스턴스 타입               |
| `ai_instance_type`        | AI 티어 인스턴스 타입                |
| `db_instance_class`       | RDS 인스턴스 클래스                  |
| `db_name` / `db_username` | RDS 데이터베이스 및 유저             |
| `alb_certificate_arn`     | ACM 인증서 ARN (HTTPS 활성화)        |

### AWS Parameter Store

애플리케이션 환경변수는 AWS Parameter Store에 저장하여 관리합니다. EC2 인스턴스는 user_data에서 자동으로 Parameter Store에서 환경변수를 가져와 Docker 컨테이너에 주입합니다.

```bash
# 저장
aws ssm put-parameter \
  --name "{환경}/{서비스}/DOT_ENV"  \
  --value "$(cat .env)" \
  --type "SecureString" \
  --region ap-northeast-2

# 확인
aws ssm get-parameter \
  --name "{환경}/{서비스}/DOT_ENV"  \
  --with-decryption \
  --region ap-northeast-2 \
  --query 'Parameter.Value' \
  --output text
```
