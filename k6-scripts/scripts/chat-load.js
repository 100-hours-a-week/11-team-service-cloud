import { sleep } from 'k6';

import { vus, duration, thinkTimeMs } from './lib/config.js';
import { getTokenOrRefresh, pickTokenForVu } from './lib/auth.js';
import { analyzeAndConfirm } from './scenarios/job_posting_analyze.js';
import { applyAndEvaluate } from './scenarios/application_apply_and_evaluate.js';
import { chatBasicFlow } from './scenarios/chat_basic_flow.js';

// k6는 로컬 파일을 open()으로 읽어 multipart에 넣는 패턴이 안정적입니다.
const resumeBytes = open('../fixtures/resume.pdf', 'b');
const portfolioBytes = open('../fixtures/portfolio.pdf', 'b');

export const options = {
  vus: vus(),
  duration: duration(),
  thresholds: {
    http_req_failed: ['rate<0.02'],
    http_req_duration: ['p(95)<2500'],
  },
};

export function setup() {
  // 토큰 전략:
  // 1) ACCESS_TOKENS=token1,token2,... 가 있으면 그걸 token pool로 사용
  // 2) 없으면 REFRESH_TOKEN 또는 ACCESS_TOKEN 단일 사용
  // 3) LOADTEST_SECRET이 있으면 loadtest 토큰 배치 발급 API 사용
  return getTokenOrRefresh();
}

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

  sleep(thinkTimeMs() / 1000);
}