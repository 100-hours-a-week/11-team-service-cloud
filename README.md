# Cloud Infrastructure

Ubuntu 서버 초기 환경 구성, 빌드, 배포를 위한 인프라 스크립트

## 구조

```
cloud/
├── Makefile
├── .env.example          # 환경변수 템플릿
├── .gitignore
├── configs/
│   └── nginx/default.conf
└── scripts/
    ├── setup/
    │   ├── setup.sh            # 전체 환경 세팅
    │   ├── setup-source.sh     # 소스코드 + 개발 환경
    │   ├── setup-mysql.sh      # MySQL만
    │   ├── install/            # 패키지 설치
    │   │   ├── aws-cli.sh
    │   │   ├── nginx.sh
    │   │   ├── java.sh
    │   │   ├── node.sh
    │   │   ├── python.sh
    │   │   └── mysql.sh
    │   └── config/             # 설정 적용
    │       ├── nginx.sh
    │       └── mysql.sh
    ├── build/
    │   └── build.sh            # FE + BE + AI 빌드
    └── deploy/
        └── deploy.sh           # 서비스 start/stop/restart
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
make help            # 명령어 목록

# 환경 세팅
make setup-all       # 전체 환경 (Git, Nginx, Java, Node, Python, MySQL)
make setup-source    # 소스코드 클론 + 개발 환경
make setup-mysql     # MySQL만

# 빌드
make build-all       # FE + BE + AI 빌드

# 배포
make deploy-all      # 재시작 (stop → start)
make deploy-start    # 시작
make deploy-stop     # 종료
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
| `BACKEND_JAR`   | Spring Boot JAR 파일명  |

버전 관련 변수(`JDK_VERSION`, `NODE_VERSION` 등)도 `.env`에서 관리됩니다.

## 자동 배포 (CI/CD)

이 프로젝트는 GitHub Actions를 사용하여 각 서비스(Frontend, Backend, AI)의 독립적인 자동 배포를 지원합니다. `main` 브랜치에 코드가 푸시되면 해당 서비스의 배포 파이프라인이 자동으로 실행됩니다.
