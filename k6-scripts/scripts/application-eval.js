import { sleep } from 'k6';

import { vus, duration, thinkTimeMs } from './lib/config.js';
import { getTokenOrRefresh } from './lib/auth.js';
import { analyzeAndConfirm } from './scenarios/job_posting_analyze.js';
import { applyAndEvaluate } from './scenarios/application_apply_and_evaluate.js';

// k6는 로컬 파일을 open()으로 읽어 multipart에 넣는 패턴이 안정적입니다.
// (TextEncoder가 없는 구버전 대비)
const resumeBytes = open('../fixtures/resume.pdf', 'b');
const portfolioBytes = open('../fixtures/portfolio.pdf', 'b');

export const options = {
  vus: vus(),
  duration: duration(),
  thresholds: {
    http_req_failed: ['rate<0.02'],
    http_req_duration: ['p(95)<4000'],
  },
};

export function setup() {
  return getTokenOrRefresh();
}

export default function (data) {
  const jobMasterId = analyzeAndConfirm(data.accessToken);
  if (jobMasterId) {
    applyAndEvaluate(data.accessToken, jobMasterId, resumeBytes, portfolioBytes);
  }
  sleep(thinkTimeMs() / 1000);
}
