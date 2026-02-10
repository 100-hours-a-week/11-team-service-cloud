# k6-scripts

이 폴더는 **11-team-service-be**(Spring) API에 대한 k6 부하테스트 스크립트를 담습니다.

## 핵심 제약 (중요)

- **OAuth(카카오) 로그인 UI 플로우를 k6로 자동화하지 않습니다.**
  - 대신 **사전에 발급받은 `ACCESS_TOKEN`** 또는 **`REFRESH_TOKEN`** 을 환경변수로 주입해서 테스트합니다.
- **AI 비용 발생 API는 stub으로 우회합니다.**
  - 공고 분석: BE → AI 서비스 `/ai/api/v1/job-posting/analyze`
  - 이력서/포트폴리오 점수 산출(평가): BE → AI 서비스 `/ai/api/v1/applicant/evaluate`

따라서 부하테스트 환경에서 **BE의 `ai.service.url`을 stub 서버로 지정**하세요.

## 1) AI Stub 서버 실행

```bash
cd k6-scripts
node stub-ai/server.js
# or
PORT=9010 node stub-ai/server.js
```

BE 설정 예시:

- `ai.service.url=http://127.0.0.1:9010`

## 2) 토큰 준비 (OAuth 문제 우회)

### 권장(Loadtest): 테스트용 토큰 배치 발급 API 사용
BE를 `loadtest` 프로파일로 실행하고, 아래 API로 VU 수만큼 토큰을 한 번에 발급받아 사용합니다.

- `GET /api/v1/auth/test/tokens?count=N`
- Header: `X-Test-Secret: <LOADTEST_SECRET>`

k6는 `LOADTEST_SECRET`이 설정되어 있으면, `setup()` 단계에서 자동으로 위 API를 호출해 토큰 풀을 만들고 VU별로 분배합니다.

```bash
LOADTEST_SECRET='...' \
TARGET_BASE_URL=http://127.0.0.1:8080 \
VUS=50 DURATION=1m \
  k6 run scripts/chat-load.js
```

### Refresh Token 사용
프론트에서 카카오 로그인 후 얻은 refreshToken을 사용:

- `REFRESH_TOKEN=...`

k6는 `setup()`에서 아래 API로 accessToken을 매번 갱신합니다.

- `POST /api/v1/auth/kakao/refresh` `{ "refreshToken": "..." }`

### 대안: Access Token 직접 주입

- `ACCESS_TOKEN=...`

(만료되면 실패합니다.)

## 3) 환경변수(.env) 설정

k6는 `.env`를 자동으로 읽지 않으므로, 실행 전에 shell에서 로드하세요.

```bash
cd k6-scripts
cp .env.example .env
# .env 편집 후
set -a
source .env
set +a
```

## 4) k6 실행

### Quick (읽기 위주)
```bash
TARGET_BASE_URL=http://127.0.0.1:8080 \
  k6 run scripts/quick.js
```

### 공고 분석 + 등록(confirm)
```bash
TARGET_BASE_URL=http://127.0.0.1:8080 \
ACCESS_TOKEN='...' \
  k6 run scripts/job-analysis.js
```

### 지원서 제출 + 평가 요청 + 짧은 결과 polling
```bash
TARGET_BASE_URL=http://127.0.0.1:8080 \
ACCESS_TOKEN='...' \
  k6 run scripts/application-eval.js
```

### 채팅 기본 플로우(채팅방 생성/입장/메시지 전송/조회)
```bash
TARGET_BASE_URL=http://127.0.0.1:8080 \
ACCESS_TOKEN='...' \
  k6 run scripts/chat-load.js
```

여러 유저를 더 현실적으로 흉내내려면(각 VU가 서로 다른 userId로 행동):

```bash
ACCESS_TOKENS='token1,token2,token3,...' \
TARGET_BASE_URL=http://127.0.0.1:8080 \
  k6 run scripts/chat-load.js
```

부하 강도 조절:

```bash
VUS=50 DURATION=1m THINK_TIME_MS=100 \
TARGET_BASE_URL=http://127.0.0.1:8080 ACCESS_TOKEN='...' \
  k6 run scripts/application-eval.js
```

## 시나리오 구성

- `scripts/quick.js`: 공고 목록 조회 (익명 가능)
- `scripts/job-analysis.js`: 공고 URL 분석(POST) + 등록(PATCH)
- `scripts/application-eval.js`: 공고 생성 → 지원서 제출 → AI 평가 요청 → 결과 조회

## 주의

- `JobPostingAnalysisService.normalizeUrl()`이 일부 query param을 제거합니다.
  - k6는 `k6_vu`, `k6_iter` 파라미터로 유니크 URL을 만들어 중복을 줄입니다.
- 평가 결과는 BE의 async worker에서 저장됩니다.
  - stub-ai를 사용하면 보통 빠르지만, 환경에 따라 polling 횟수/간격을 늘리세요.
