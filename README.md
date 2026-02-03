# Cloud Infrastructure

> **Version:** v0.0.3

Ubuntu 서버 초기 환경 구성, 빌드, 배포를 위한 인프라 스크립트

## 구조

```
cloud/
├── Makefile                 # 명령어 인터페이스
├── .env.example             # 환경변수 템플릿
├── configs/nginx/           # Nginx 설정 파일
├── scripts/
│   ├── setup/               # 환경 세팅 (install/, config/, ssl/)
│   └── deploy/              # 배포 스크립트
├── ci-cd/                   # GitHub Actions (frontend, backend, ai)
└── terraform/               # IaC (modules: network, compute, iam)
```

## 사전 요구사항

시작하기 전에 아래 항목들을 준비해야 합니다:

- [ ] **AWS CLI 설정**: `aws configure`로 credentials 설정
- [ ] **Terraform 설치**: [공식 문서](https://developer.hashicorp.com/terraform/install) 참고
- [ ] **SSH 키페어 생성**: AWS 콘솔에서 EC2 키페어 생성 후 `.pem` 파일 보관
- [ ] **S3 버킷 생성**: 배포 아티팩트 저장용 버킷
- [ ] **도메인 준비**: SSL 인증서 발급을 위한 도메인 및 DNS 관리 권한

## 시작하기

```bash
# 1. 환경변수 설정
cp .env.example .env
vi .env  # 환경에 맞게 수정

# 2. Parameter Store에 .env 저장 (프로덕션)
aws ssm put-parameter \
  --name "/bigbang/dot-env" \
  --value "$(cat .env)" \
  --type "SecureString" \
  --region ap-northeast-2

# 3. Terraform 변수 설정
cd terraform
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars  # SSH 키페어명, S3 버킷명 등 설정

# 4. 인프라 생성
terraform init
terraform apply

# 5. DNS 설정
# 출력된 EC2 Public IP를 SERVICE_DOMAIN에 A 레코드로 등록
```

## 사용법

```bash
make help              # 명령어 목록

# 환경 세팅
make setup-all         # 전체 환경 (Git, Nginx, Java, Node, Python, MySQL)
make setup-source      # 소스코드 클론 + 개발 환경
make setup-mysql       # MySQL만

# 배포
make deploy            # S3에서 다운로드 + 재시작 (배포)
make deploy-download   # S3에서 JAR 다운로드만
make deploy-all        # 재시작 (stop → start)
make deploy-start      # 시작
make deploy-stop       # 종료
```

## 기술 스택

| 구분           | 버전   |
| -------------- | ------ |
| Java (OpenJDK) | 21     |
| Node.js        | 22     |
| Python         | 3.11   |
| MySQL          | 8.0.44 |
| Nginx          | 1.28.1 |
| AWS CLI        | 2.x    |

## 아키텍처

```
Client → Nginx(:443) → /api/*  → Spring Boot(:8080)
                     → /*      → React Static (/var/www/frontend/build)
                                  FastAPI(:8000)
```

## 환경변수

`.env.example`을 복사하여 `.env`를 생성하고 환경에 맞게 수정:

| 변수                | 설명                           |
| ------------------- | ------------------------------ |
| `JDK_VERSION`       | Java 버전 (기본: 21)           |
| `NODE_VERSION`      | Node.js 버전 (기본: 22)        |
| `PYTHON_VERSION`    | Python 버전 (기본: 3.11)       |
| `MYSQL_VERSION`     | MySQL 버전 (기본: 8.0.44)      |
| `NGINX_VERSION`     | Nginx 버전 (기본: 1.28.1)      |
| `DB_SCHEMA`         | MySQL 데이터베이스명           |
| `DB_USER`           | MySQL 유저명                   |
| `DB_PASSWORD`       | MySQL 비밀번호                 |
| `SERVER_ENV_PATH`   | 서버 환경변수 파일 경로        |
| `SERVICE_DOMAIN`    | 서비스 도메인                  |
| `CERTBOT_EMAIL`     | SSL 인증서 발급용 이메일       |
| `S3_BUCKET`         | 릴리즈 S3 버킷명               |
| `S3_BACKEND_PREFIX` | S3 백엔드 아티팩트 경로        |

### AWS Parameter Store 사용 (프로덕션 환경)

프로덕션 환경에서는 `.env` 파일을 AWS Parameter Store에 저장하여 안전하게 관리합니다.

#### 1. .env 파일 생성 및 수정

```bash
cd cloud
cp .env.example .env
vi .env  # 실제 값으로 수정
```

#### 2. Parameter Store에 저장

```bash
aws ssm put-parameter \
  --name "/bigbang/dot-env" \
  --value "$(cat .env)" \
  --type "SecureString" \
  --region ap-northeast-2 \
  --description "BigBang service .env configuration"
```

#### 3. 저장 확인

```bash
aws ssm get-parameter \
  --name "/bigbang/dot-env" \
  --with-decryption \
  --region ap-northeast-2 \
  --query 'Parameter.Value' \
  --output text
```

#### 4. 값 업데이트

```bash
aws ssm put-parameter \
  --name "/bigbang/dot-env" \
  --value "$(cat .env)" \
  --type "SecureString" \
  --region ap-northeast-2 \
  --overwrite
```

Terraform으로 EC2 인스턴스를 생성하면 user_data에서 자동으로 Parameter Store에서 `.env`를 가져와 사용합니다.

## 자동 배포 (CI/CD)

GitHub Actions를 사용하여 각 서비스(Frontend, Backend, AI)의 독립적인 자동 배포를 지원합니다.

| 서비스 | CI 워크플로우 | CD 워크플로우 |
|--------|---------------|---------------|
| Frontend | `ci-cd/frontend/ci.yml` | `ci-cd/frontend/cd.yml` |
| Backend | `ci-cd/backend/ci.yml` | `ci-cd/backend/cd.yml` |
| AI | `ci-cd/ai/ci.yml` | `ci-cd/ai/cd.yml` |

`main` 브랜치에 코드가 푸시되면 해당 서비스의 배포 파이프라인이 자동으로 실행됩니다.

## Terraform (IaC)

AWS 인프라를 코드로 관리합니다. 모듈화된 구조로 리소스를 관리합니다.

### 모듈 구조

| 모듈 | 설명 |
| ---- | ---- |
| `modules/network` | VPC, Subnet, Security Group, Internet Gateway, Route Table, Elastic IP |
| `modules/compute` | EC2 인스턴스 |
| `modules/iam` | IAM 역할 및 권한 (Parameter Store, S3 읽기 권한) |

### 주요 파일

- **provider.tf**: AWS 프로바이더 설정
- **terraform.tf**: Terraform 백엔드 설정
- **variables.tf**: 입력 변수 정의
- **terraform.tfvars.example**: 변수 값 템플릿

### 사용법

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars  # 환경에 맞게 수정

terraform init      # 초기화
terraform plan      # 변경 사항 미리보기
terraform apply     # 인프라 적용
```

### terraform.tfvars 설정

```hcl
deployment_buckets = ["your-deployment-bucket"]
ssh_key_name = "my-key-pair"
# allowed_ssh_cidrs = ["203.0.113.5/32"]  # SSH 접근 IP 제한 (선택)
```

### EC2 초기화 과정 (user_data)

EC2 인스턴스 생성 시 자동으로 실행:

1. 패키지 업데이트 및 필수 도구 설치 (make, wget, awscli)
2. GitHub에서 프로젝트 코드 다운로드 (develop 브랜치)
3. AWS Parameter Store에서 `.env` 파일 가져오기
4. `make setup-all`로 전체 환경 세팅
5. Nginx 설치 및 SSL 인증서 자동 발급 (Certbot)

### DNS 설정 (필수)

> **주의:** SSL 인증서 발급을 위해 DNS 설정이 **즉시** 필요합니다.

Terraform으로 EC2 인스턴스 생성 후, user_data 스크립트가 자동으로 Let's Encrypt SSL 인증서 발급을 시도합니다. 이 과정에서 Certbot이 도메인 소유권을 검증하기 때문에, **인스턴스 생성 직후** `.env`의 `SERVICE_DOMAIN`이 해당 인스턴스의 Public IP를 가리키도록 DNS 레코드를 설정해야 합니다.

**설정 순서:**

1. `terraform apply`로 EC2 인스턴스 생성
2. 출력된 Public IP 또는 Elastic IP 확인
3. DNS 관리 콘솔에서 A 레코드 설정:
   - Host: `SERVICE_DOMAIN` 값 (예: `example.kr`)
   - Value: EC2 인스턴스 Public IP
4. DNS 전파 완료 후 SSL 인증서가 자동 발급됨

DNS 설정이 늦어지면 Certbot이 실패하며, 이 경우 인스턴스에 접속하여 수동으로 SSL 설정을 진행해야 합니다:

```bash
sudo /home/ubuntu/cloud/scripts/setup/ssl/setup-ssl.sh
```
