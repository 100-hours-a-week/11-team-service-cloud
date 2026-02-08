import { sleep } from 'k6';

import { vus, duration, thinkTimeMs } from './lib/config.js';
import { getTokenOrRefresh, pickTokenForVu } from './lib/auth.js';
import { analyzeAndConfirm } from './scenarios/job_posting_analyze.js';

export const options = {
  vus: vus(),
  duration: duration(),
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<2500'],
  },
};

export function setup() {
  return getTokenOrRefresh();
}

export default function (data) {
  const token = pickTokenForVu(data);
  analyzeAndConfirm(token);
  sleep(thinkTimeMs() / 1000);
}
