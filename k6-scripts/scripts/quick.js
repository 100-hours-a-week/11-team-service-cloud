import { sleep } from 'k6';

import { vus, duration } from './lib/config.js';
import { browseJobPostings } from './scenarios/browse_job_postings.js';
import { createApiHandleSummary } from './lib/summary.js';

export const options = {
  vus: vus(),
  duration: duration(),

  systemTags: ['status', 'method', 'name', 'group', 'scenario'],

  summaryTrendStats: ['count', 'avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],

  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1500'],

    'http_req_duration{api:job-postings.list}': ['p(95)<1500'],
    'http_req_failed{api:job-postings.list}': ['rate<0.01'],
  },
};

export const handleSummary = createApiHandleSummary(['job-postings.list']);

export default function (data) {
  // quick는 '읽기' 위주의 트래픽 (익명 접근 가능)
  browseJobPostings();
}
