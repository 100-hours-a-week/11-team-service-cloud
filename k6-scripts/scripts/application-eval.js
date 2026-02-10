import { sleep } from 'k6';

import { vus, duration, thinkTimeMs } from './lib/config.js';
import { getTokenOrRefresh, pickTokenForVu } from './lib/auth.js';
import { analyzeAndConfirm } from './scenarios/job_posting_analyze.js';
import { applyAndEvaluate } from './scenarios/application_apply_and_evaluate.js';
import { createApiHandleSummary } from './lib/summary.js';

// k6는 로컬 파일을 open()으로 읽어 multipart에 넣는 패턴이 안정적입니다.
// (TextEncoder가 없는 구버전 대비)
const resumeBytes = open('../fixtures/resume.pdf', 'b');
const portfolioBytes = open('../fixtures/portfolio.pdf', 'b');

export const options = {
  vus: vus(),
  duration: duration(),

  systemTags: ['status', 'method', 'name', 'group', 'scenario'],

  summaryTrendStats: ['count', 'avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],

  thresholds: {
    http_req_failed: ['rate<0.02'],
    http_req_duration: ['p(95)<4000'],

    'http_req_duration{api:job-postings.analyze}': ['p(95)<1500'],
    'http_req_failed{api:job-postings.analyze}': ['rate<0.01'],

    'http_req_duration{api:job-postings.confirm}': ['p(95)<1500'],
    'http_req_failed{api:job-postings.confirm}': ['rate<0.01'],

    'http_req_duration{api:applications.apply}': ['p(95)<2500'],
    'http_req_failed{api:applications.apply}': ['rate<0.02'],

    'http_req_duration{api:applications.request-analyses}': ['p(95)<2500'],
    'http_req_failed{api:applications.request-analyses}': ['rate<0.02'],

    'http_req_duration{api:applications.get-analysis}': ['p(95)<2500'],
    'http_req_failed{api:applications.get-analysis}': ['rate<0.02'],
  },
};

export const handleSummary = createApiHandleSummary([
  'job-postings.analyze',
  'job-postings.confirm',
  'applications.apply',
  'applications.request-analyses',
  'applications.get-analysis',
]);

export function setup() {
  return getTokenOrRefresh();
}

export default function (data) {
  const token = pickTokenForVu(data);

  const jobMasterId = analyzeAndConfirm(token);
  if (jobMasterId) {
    applyAndEvaluate(token, jobMasterId, resumeBytes, portfolioBytes);
  }
}
