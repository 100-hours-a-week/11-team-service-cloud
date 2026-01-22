# Cloud Infrastructure

Ubuntu 서버 초기 환경 구성을 위한 인프라 스크립트 모음

## 구조

```
cloud/
├── Makefile                    # 실행 진입점
├── configs/
│   └── nginx/
│       └── default.conf        # Nginx 설정 (HTTPS, 리버스 프록시)
└── scripts/
    ├── setup/
    │   ├── setup.sh            # 전체 환경 세팅
    │   ├── setup-source.sh     # 소스코드 + 개발 환경
    │   └── setup-mysql.sh      # MySQL만 설치/설정
    ├── build/                  # 빌드 스크립트
    │   └── build.sh            # FE + BE + AI 빌드 스크립트
    └── deploy/                 # 배포 스크립트
        └── deploy.sh           # FE + BE + AI 배포 스크립트
```

## 사용법

```bash
# 명령어 목록 확인
make help

# 전체 환경 세팅 (Git, Nginx, Java, Node, Python, MySQL)
make setup-all

# 소스코드 클론 및 개발 환경만 설치
make setup-source

# MySQL만 설치 및 설정
make setup-mysql
```

## 기술 스택

| 구분           | 버전   |
| -------------- | ------ |
| Java (OpenJDK) | 21     |
| Node.js        | 22     |
| Python         | 3.11   |
| MySQL          | latest |
| Nginx          | latest |

## 아키텍처

```
[Client] → [Nginx:443] → /api/*  → [Backend:8080]
                       → /*      → [Frontend Static]
```

## 설정 변경

스크립트 실행 전 아래 파일들의 변수를 환경에 맞게 수정:

- `scripts/setup/setup.sh` - 레포지토리 URL, DB 정보
- `scripts/setup/setup-source.sh` - 레포지토리 URL
- `scripts/setup/setup-mysql.sh` - DB 스키마, 유저, 비밀번호
- `configs/nginx/default.conf` - 도메인, SSL 인증서 경로
