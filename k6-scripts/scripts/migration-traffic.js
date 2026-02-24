/**
 * migration-traffic.js
 *
 * 무중단 DB 마이그레이션 테스트용 지속 트래픽 생성기.
 * 읽기/쓰기를 혼합하여 실제 서비스와 유사한 부하를 만들고,
 * 마이그레이션 수행 중 에러율 변화를 관찰할 수 있다.
 *
 * Usage:
 *   LOADTEST_SECRET='...' \
 *   TARGET_BASE_URL=http://127.0.0.1:8080 \
 *   VUS=10 DURATION=10m THINK_TIME_MS=100 \
 *     k6 run scripts/migration-traffic.js
 */

import http from 'k6/http';
import { sleep, check } from 'k6';
import { Counter, Trend, Rate } from 'k6/metrics';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.1.0/index.js';

import { vus, duration, thinkTimeMs, getBaseUrl } from './lib/config.js';
import { getTokenOrRefresh, pickTokenForVu } from './lib/auth.js';
import { getJson, postJson, patchJson, authHeaders } from './lib/http.js';

const resumeBytes = open('../fixtures/resume.pdf', 'b');
const portfolioBytes = open('../fixtures/portfolio.pdf', 'b');

// 실제 유저처럼 think time에 랜덤 편차를 준다 (50%~150%)
function randomThink() {
  const base = thinkTimeMs();
  const jitter = base * (0.5 + Math.random());
  return jitter / 1000;
}

// 타임스탬프 포맷 (KST)
function kstNow() {
  const d = new Date(Date.now() + 9 * 3600 * 1000);
  return d.toISOString().replace('T', ' ').substring(0, 19);
}

// -- custom metrics --
const writeErrors = new Counter('write_errors');
const readErrors = new Counter('read_errors');
const writeLatency = new Trend('write_latency', true);
const readLatency = new Trend('read_latency', true);
const errorRate = new Rate('error_rate');

export const options = {
  scenarios: {
    readers: {
      executor: 'constant-vus',
      vus: Math.max(1, Math.floor(vus() * 0.0)),
      duration: duration(),
      exec: 'readTraffic',
    },
    writers: {
      executor: 'constant-vus',
      vus: Math.max(1, Math.ceil(vus() * 1.0)),
      duration: duration(),
      exec: 'writeTraffic',
    },
  },

  systemTags: ['status', 'method', 'name', 'group', 'scenario'],
  summaryTrendStats: ['count', 'avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],

  thresholds: {
    'http_req_duration{api:job-postings.list}': ['max>=0'],
    'http_req_duration{api:job-postings.analyze}': ['max>=0'],
    'http_req_duration{api:job-postings.confirm}': ['max>=0'],
    'http_req_duration{api:applications.apply}': ['max>=0'],
    'http_req_duration{api:applications.request-analyses}': ['max>=0'],
    'http_req_duration{api:applications.get-analysis}': ['max>=0'],
    'http_req_failed{api:job-postings.list}': ['rate>=0'],
    'http_req_failed{api:job-postings.analyze}': ['rate>=0'],
    'http_req_failed{api:job-postings.confirm}': ['rate>=0'],
    'http_req_failed{api:applications.apply}': ['rate>=0'],
    'http_req_failed{api:applications.request-analyses}': ['rate>=0'],
    'http_req_failed{api:applications.get-analysis}': ['rate>=0'],
  },
};

// summary: k6 기본 텍스트 + 커스텀 메트릭 강조
export function handleSummary(data) {
  const lines = [];
  lines.push('\n========== MIGRATION TEST SUMMARY ==========\n');

  // 커스텀 메트릭 출력
  const metrics = [
    ['write_errors', data.metrics?.write_errors?.values?.count],
    ['read_errors', data.metrics?.read_errors?.values?.count],
    ['error_rate', data.metrics?.error_rate?.values?.rate],
    ['write_latency p(95)', data.metrics?.write_latency?.values?.['p(95)']],
    ['read_latency p(95)', data.metrics?.read_latency?.values?.['p(95)']],
  ];

  for (const [name, value] of metrics) {
    if (value !== undefined && value !== null) {
      const display = name.includes('rate') ? `${(value * 100).toFixed(2)}%` :
                      name.includes('latency') ? `${value.toFixed(2)}ms` :
                      String(value);
      lines.push(`  ${name}: ${display}`);
    }
  }

  // API별 에러 카운트
  lines.push('\n--- API Error Breakdown ---');
  const apis = [
    'job-postings.list', 'job-postings.analyze', 'job-postings.confirm',
    'applications.apply', 'applications.request-analyses', 'applications.get-analysis',
  ];
  for (const api of apis) {
    const failed = data.metrics?.[`http_req_failed{api:${api}}`]?.values;
    const dur = data.metrics?.[`http_req_duration{api:${api}}`]?.values;
    const count = dur?.count ?? 0;
    const failRate = failed?.rate ?? 0;
    const p95 = dur?.['p(95)'] ?? 0;
    lines.push(`  ${api}: ${count} reqs, fail ${(failRate * 100).toFixed(2)}%, p95 ${p95.toFixed(0)}ms`);
  }

  lines.push('\n============================================\n');

  return {
    stdout: lines.join('\n') + '\n' + textSummary(data, { indent: '  ', enableColors: true }),
  };
}

export function setup() {
  console.log(`[${kstNow()}] === Migration traffic test started ===`);
  return getTokenOrRefresh();
}

export function teardown() {
  console.log(`[${kstNow()}] === Migration traffic test finished ===`);
}

// 에러 로깅 헬퍼
function logError(api, status, vuId, iter) {
  console.error(`[${kstNow()}] ERROR ${api} status=${status} vu=${vuId} iter=${iter}`);
}

// ============================================================
// 읽기 시나리오
// ============================================================
export function readTraffic(data) {
  const baseUrl = getBaseUrl();
  const token = pickTokenForVu(data);

  const page = Math.floor(Math.random() * 5);
  const listRes = getJson(
    `${baseUrl}/api/v1/job-postings?size=20&page=${page}&status=OPEN&sort=DEADLINE_ASC`,
    {
      ...authHeaders(token),
      tags: { api: 'job-postings.list', name: 'job-postings.list' },
    }
  );

  readLatency.add(listRes.timings.duration);
  const ok = check(listRes, {
    'job-postings.list status 200': (r) => r.status === 200,
  });

  if (!ok) {
    readErrors.add(1);
    errorRate.add(1);
    logError('job-postings.list', listRes.status, __VU, __ITER);
  } else {
    errorRate.add(0);
  }

  sleep(randomThink());
}

// ============================================================
// 쓰기 시나리오
// ============================================================
export function writeTraffic(data) {
  const baseUrl = getBaseUrl();
  const token = pickTokenForVu(data);

  // 1) 공고 분석 (POST)
  const uniqueUrl = `https://example.com/jobs/migration-test/k6-${__VU}-${__ITER}-${Date.now()}`;
  const analyzeRes = postJson(
    `${baseUrl}/api/v1/job-postings`,
    { url: uniqueUrl },
    {
      ...authHeaders(token),
      tags: { api: 'job-postings.analyze', name: 'job-postings.analyze' },
    }
  );

  writeLatency.add(analyzeRes.timings.duration);
  const analyzeOk = check(analyzeRes, {
    'job-postings.analyze status 200': (r) => r.status === 200,
  });

  if (!analyzeOk) {
    writeErrors.add(1);
    errorRate.add(1);
    logError('job-postings.analyze', analyzeRes.status, __VU, __ITER);
    sleep(randomThink());
    return;
  }
  errorRate.add(0);

  const jobMasterId = analyzeRes.json()?.data?.jobMasterId;
  if (!jobMasterId) {
    sleep(randomThink());
    return;
  }

  sleep(randomThink());

  // 2) 공고 등록 (PATCH)
  const confirmRes = patchJson(
    `${baseUrl}/api/v1/job-postings/${jobMasterId}`,
    { registrationStatus: 'CONFIRMED' },
    {
      ...authHeaders(token),
      tags: { api: 'job-postings.confirm', name: 'job-postings.confirm' },
    }
  );

  writeLatency.add(confirmRes.timings.duration);
  const confirmOk = check(confirmRes, {
    'job-postings.confirm status 200': (r) => r.status === 200,
  });

  if (!confirmOk) {
    writeErrors.add(1);
    errorRate.add(1);
    logError('job-postings.confirm', confirmRes.status, __VU, __ITER);
  } else {
    errorRate.add(0);
  }

  sleep(randomThink());

  // 3) 지원서 제출 (multipart POST)
  const formData = {
    jobPostingId: String(jobMasterId),
    resume: http.file(resumeBytes, `resume-${__VU}-${__ITER}.pdf`, 'application/pdf'),
  };
  if (portfolioBytes) {
    formData.portfolio = http.file(portfolioBytes, `portfolio-${__VU}-${__ITER}.pdf`, 'application/pdf');
  }

  const applyRes = http.post(`${baseUrl}/api/v1/applications`, formData, {
    headers: { Authorization: `Bearer ${token}` },
    tags: { api: 'applications.apply', name: 'applications.apply' },
  });

  writeLatency.add(applyRes.timings.duration);
  const applyOk = check(applyRes, {
    'applications.apply status 200': (r) => r.status === 200,
  });

  if (!applyOk) {
    writeErrors.add(1);
    errorRate.add(1);
    logError('applications.apply', applyRes.status, __VU, __ITER);
    sleep(randomThink());
    return;
  }
  errorRate.add(0);

  const applicationId = applyRes.json()?.data;
  if (!applicationId) {
    sleep(randomThink());
    return;
  }

  sleep(randomThink());

  // 4) AI 평가 요청 (POST)
  const evalRes = postJson(
    `${baseUrl}/api/v1/applications/${applicationId}/analyses`,
    { analysis_type: 'EVALUATION' },
    {
      ...authHeaders(token),
      tags: { api: 'applications.request-analyses', name: 'applications.request-analyses' },
      responseCallback: http.expectedStatuses(200, 202, 409),
    }
  );

  writeLatency.add(evalRes.timings.duration);
  const evalOk = check(evalRes, {
    'applications.request-analyses status ok': (r) => [200, 202, 409].includes(r.status),
  });

  if (!evalOk) {
    writeErrors.add(1);
    errorRate.add(1);
    logError('applications.request-analyses', evalRes.status, __VU, __ITER);
  } else {
    errorRate.add(0);
  }

  sleep(randomThink());

  // 5) 결과 조회 (GET) — 짧게 polling
  const maxAttempts = parseInt(__ENV.EVAL_POLL_ATTEMPTS || '5', 10);
  const intervalMs = parseInt(__ENV.EVAL_POLL_INTERVAL_MS || '500', 10);

  for (let i = 0; i < maxAttempts; i++) {
    const res = http.get(`${baseUrl}/api/v1/applications/${applicationId}/analyses`, {
      headers: { Authorization: `Bearer ${token}` },
      tags: { api: 'applications.get-analysis', name: 'applications.get-analysis' },
    });

    readLatency.add(res.timings.duration);
    const pollOk = check(res, {
      'applications.get-analysis status 200': (r) => r.status === 200,
    });

    if (!pollOk) {
      readErrors.add(1);
      errorRate.add(1);
      logError('applications.get-analysis', res.status, __VU, __ITER);
    } else {
      errorRate.add(0);
      const overall = res.json()?.data?.overallScore;
      if (overall !== undefined && overall !== null) break;
    }

    sleep(intervalMs / 1000);
  }

  sleep(randomThink());
}
