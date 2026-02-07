import { sleep } from 'k6';

import { vus, duration, thinkTimeMs } from './lib/config.js';
import { getTokenOrRefresh, pickTokenForVu } from './lib/auth.js';
import { analyzeAndConfirm } from './scenarios/job_posting_analyze.js';
import { chatBasicFlow } from './scenarios/chat_basic_flow.js';

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
  return getTokenOrRefresh();
}

export default function (data) {
  const token = pickTokenForVu(data);

  const jobMasterId = analyzeAndConfirm(token);
  if (jobMasterId) {
    chatBasicFlow(token, jobMasterId);
  }

  sleep(thinkTimeMs() / 1000);
}
