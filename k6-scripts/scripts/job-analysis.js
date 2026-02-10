import { sleep } from 'k6';

import { vus, duration, thinkTimeMs } from './lib/config.js';
import { getTokenOrRefresh, pickTokenForVu } from './lib/auth.js';
import { analyzeAndConfirm } from './scenarios/job_posting_analyze.js';
import { createApiHandleSummary } from './lib/summary.js';

export const options = {
  vus: vus(),
  duration: duration(),

  systemTags: ['status', 'method', 'name', 'group', 'scenario'],

  summaryTrendStats: ['count', 'avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],

  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<2500'],

    'http_req_duration{api:job-postings.analyze}': ['p(95)<1500'],
    'http_req_failed{api:job-postings.analyze}': ['rate<0.01'],

    'http_req_duration{api:job-postings.confirm}': ['p(95)<1500'],
    'http_req_failed{api:job-postings.confirm}': ['rate<0.01'],
  },
};

export const handleSummary = createApiHandleSummary([
  'job-postings.analyze',
  'job-postings.confirm',
]);

export function setup() {
  return getTokenOrRefresh();
}

export default function (data) {
  const token = pickTokenForVu(data);
  analyzeAndConfirm(token);
  sleep(thinkTimeMs() / 1000);
}
