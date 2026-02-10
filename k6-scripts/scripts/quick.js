import { sleep } from 'k6';

import { vus, duration, thinkTimeMs } from './lib/config.js';
import { getTokenOrRefresh } from './lib/auth.js';
import { browseJobPostings } from './scenarios/browse_job_postings.js';
import { createApiHandleSummary } from './lib/summary.js';

export const options = {
  vus: vus(),
  duration: duration(),
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1500'],
  },

export const handleSummary = createApiHandleSummary(['job-postings.list']);
};

export function setup() {
  return getTokenOrRefresh();
}

export default function (data) {
  // quick는 '읽기' 위주의 트래픽 (익명 접근 가능)
  browseJobPostings();
  sleep(thinkTimeMs() / 1000);
}
