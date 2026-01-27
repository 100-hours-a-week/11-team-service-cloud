# Cloud Infrastructure

Ubuntu 서버 초기 환경 구성, 빌드, 배포를 위한 인프라 스크립트

## 구조

```
cloud/
├── Makefile              # 명령어 인터페이스
├── .env.example          # 환경변수 템플릿
├── configs/
│   └── nginx/default.conf
├── scripts/
│   ├── setup/
│   │   ├── setup.sh            # 전체 환경 세팅
│   │   ├── setup-source.sh     # 소스코드 + 개발 환경
│   │   ├── setup-mysql.sh      # MySQL만
│   │   ├── install/            # 패키지 설치
│   │   │   ├── aws-cli.sh
│   │   │   ├── nginx.sh
│   │   │   ├── java.sh
│   │   │   ├── node.sh
│   │   │   ├── python.sh
│   │   │   └── mysql.sh
│   │   └── config/             # 설정 적용
│   │       ├── nginx.sh
│   │       └── mysql.sh
│   └── deploy/
│       └── deploy.sh           # 서비스 start/stop/restart
├── ci-cd/                      # GitHub Actions 워크플로우
│   ├── ai/                     # AI 서비스 CI/CD
│   ├── backend/                # 백엔드 CI/CD
│   └── frontend/               # 프론트엔드 CI/CD
└── terraform/                  # IaC 설정 (AWS 인프라)
    ├── main.tf
    ├── provider.tf
    └── terraform.tf
```

## 시작하기

```bash
# 1. make 설치
sudo apt install make

# 2. 환경변수 설정
cp .env.example .env
vi .env  # 환경에 맞게 수정
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
| MySQL          | 8.0.xx |
| Nginx          | 1.28.1 |
| AWS CLI        | 2.x.x  |

## 아키텍처

```
Client → Nginx(:443) → /api/*  → Spring Boot(:8080)
                     → /*      → React Static (/var/www/frontend/build)
                                  FastAPI(:8000)
```

## 환경변수

`.env.example`을 복사하여 `.env`를 생성하고 환경에 맞게 수정:

| 변수            | 설명                    |
| --------------- | ----------------------- |
| `FRONTEND_REPO` | 프론트엔드 Git 레포 URL |
| `BACKEND_REPO`  | 백엔드 Git 레포 URL     |
| `FASTAPI_REPO`  | AI Git 레포 URL         |
| `DB_SCHEMA`     | MySQL 데이터베이스명    |
| `DB_USER`       | MySQL 유저명            |
| `DB_PASSWORD`   | MySQL 비밀번호          |
| `S3_BUCKET`     | 릴리즈 S3 버킷명        |
| `S3_BACKEND_PREFIX` | S3 백엔드 아티팩트 경로 |
| `SERVER_ENV_PATH`   | 서버 환경변수 파일 경로 |

버전 관련 변수(`JDK_VERSION`, `NODE_VERSION` 등)도 `.env`에서 관리됩니다.

## 자동 배포 (CI/CD)

GitHub Actions를 사용하여 각 서비스(Frontend, Backend, AI)의 독립적인 자동 배포를 지원합니다.

| 서비스 | CI 워크플로우 | CD 워크플로우 |
|--------|---------------|---------------|
| Frontend | `ci-cd/frontend/ci.yml` | `ci-cd/frontend/cd.yml` |
| Backend | `ci-cd/backend/ci.yml` | `ci-cd/backend/cd.yml` |
| AI | `ci-cd/ai/ci.yml` | `ci-cd/ai/cd.yml` |

`main` 브랜치에 코드가 푸시되면 해당 서비스의 배포 파이프라인이 자동으로 실행됩니다.

## Terraform (IaC)

AWS 인프라를 코드로 관리합니다.

```bash
cd terraform
terraform init      # 초기화
terraform plan      # 변경 사항 미리보기
terraform apply     # 인프라 적용
```
