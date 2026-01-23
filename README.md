# Cloud Infrastructure

Ubuntu 서버 초기 환경 구성, 빌드, 배포를 위한 인프라 스크립트

## 구조

```
cloud/
├── Makefile
├── configs/
│   └── nginx/default.conf
└── scripts/
    ├── setup/
    │   ├── setup.sh            # 전체 환경 세팅
    │   ├── setup-source.sh     # 소스코드 + 개발 환경
    │   └── setup-mysql.sh      # MySQL 설치/설정
    ├── build/
    │   └── build.sh            # FE + BE + AI 빌드
    └── deploy/
        └── deploy.sh           # 서비스 start/stop/restart
```

## 사용법

```bash
# make 설치
sudo apt install make
```

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

| 구분 | 버전 |
|------|------|
| Java (OpenJDK) | 21 |
| Node.js | 22 |
| Python | 3.11 |
| MySQL | latest |
| Nginx | latest |

## 아키텍처

```
Client → Nginx(:443) → /api/*  → Spring Boot(:8080)
                     → /*      → React Static (/var/www/frontend/build)
                                  FastAPI(:8000)
```

## 설정 변경

스크립트 실행 전 환경에 맞게 수정 필요:

- `scripts/setup/*.sh` - 레포 URL, DB 정보, 런타임 버전
- `scripts/deploy/deploy.sh` - JAR 파일명
- `configs/nginx/default.conf` - 도메인, SSL 인증서 경로
