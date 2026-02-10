import { sleep } from 'k6';

import { vus, duration, thinkTimeMs } from './lib/config.js';
import { getTokenOrRefresh, pickTokenForVu } from './lib/auth.js';
import { analyzeAndConfirm } from './scenarios/job_posting_analyze.js';
import { applyAndEvaluate } from './scenarios/application_apply_and_evaluate.js';
import { chatBasicFlow } from './scenarios/chat_basic_flow.js';
import { createApiHandleSummary } from './lib/summary.js';

// k6는 로컬 파일을 open()으로 읽어 multipart에 넣는 패턴이 안정적입니다.
const resumeBytes = open('../fixtures/resume.pdf', 'b');
const portfolioBytes = open('../fixtures/portfolio.pdf', 'b');

export const options = {
  vus: vus(),
  duration: duration(),

  // Prometheus remote write에서 url(동적 id 포함)로 time series 폭발하는 걸 방지
  // api/name 태그로만 집계하도록 url system tag를 제외합니다.
  systemTags: ['status', 'method', 'name', 'group', 'scenario'],

  // 기본 요약 통계에 p(99)까지 포함 (stdout 가독성 ↑)
  summaryTrendStats: ['count', 'avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],

  thresholds: {
    // 전체(모든 API 합산)도 같이 두면, "전체적으로 시스템이 망가졌는지"를 한눈에 봄
    http_req_failed: ['rate<0.02'],
    http_req_duration: ['p(95)<2500'],

    // 채팅 API별 (tags: { api: '...' })
    'http_req_duration{api:chat.send-message}': ['p(95)<300'],
    'http_req_failed{api:chat.send-message}': ['rate<0.01'],

    'http_req_duration{api:chat.list-messages}': ['p(95)<800'],
    'http_req_failed{api:chat.list-messages}': ['rate<0.02'],

    'http_req_duration{api:chat.list-members}': ['p(95)<800'],
    'http_req_failed{api:chat.list-members}': ['rate<0.02'],

    // (원하면 여기도 SLA 걸 수 있음)
    'http_req_duration{api:chat.create-room}': ['p(95)<1500'],
    'http_req_failed{api:chat.create-room}': ['rate<0.02'],

    'http_req_duration{api:chat.join-room}': ['p(95)<1500'],
    'http_req_failed{api:chat.join-room}': ['rate<0.02'],
  },
};

export function setup() {
  // 토큰 전략:
  // 1) ACCESS_TOKENS=token1,token2,... 가 있으면 그걸 token pool로 사용
  // 2) 없으면 REFRESH_TOKEN 또는 ACCESS_TOKEN 단일 사용
  // 3) LOADTEST_SECRET이 있으면 loadtest 토큰 배치 발급 API 사용
  return getTokenOrRefresh();
}

export const handleSummary = createApiHandleSummary([
  'chat.create-room',
  'chat.join-room',
  'chat.send-message',
  'chat.list-messages',
  'chat.list-members',
]);

export default function (data) {
  const token = pickTokenForVu(data);

  const jobMasterId = analyzeAndConfirm(token);
  if (!jobMasterId) {
    sleep(thinkTimeMs() / 1000);
    return;
  }

  // 채팅방 생성은 "해당 공고에 지원한 사용자"만 가능하므로 먼저 지원서를 제출합니다.
  const applicationId = applyAndEvaluate(token, jobMasterId, resumeBytes, portfolioBytes);
  if (!applicationId) {
    sleep(thinkTimeMs() / 1000);
    return;
  }

  chatBasicFlow(token, jobMasterId);
}