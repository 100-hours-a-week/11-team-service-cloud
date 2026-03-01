/**
 * asg-scaling.js
 *
 * ASG(Auto Scaling Group) 스케일링 검증용 부하 테스트.
 * 단계별로 VU를 올렸다 내리며, scale-out/in이 정상 작동하는지
 * 응답시간·에러율 변화로 확인한다.
 *
 * 단계:
 *   1) Warm-up   : 소량 트래픽으로 baseline 측정
 *   2) Ramp-up   : 점진적 부하 증가 → ASG scale-out 트리거
 *   3) Peak       : 고부하 유지 → 새 인스턴스 투입 후 안정화 확인
 *   4) Ramp-down  : 부하 감소 → scale-in 유도
 *   5) Cool-down  : 소량 트래픽 → 인스턴스 축소 후에도 정상 응답 확인
 *
 * Usage:
 *   LOADTEST_SECRET='...' \
 *   TARGET_BASE_URL=https://v2-staging.scuad.kr \
 *   PEAK_VUS=100 THINK_TIME_MS=200 \
 *     k6 run scripts/asg-scaling.js
 */

import http from 'k6/http';
import { sleep, check, group } from 'k6';
import { Counter, Trend, Rate } from 'k6/metrics';

import { getBaseUrl, thinkTimeMs } from './lib/config.js';
import { getTokenOrRefresh, pickTokenForVu } from './lib/auth.js';
import { getJson, postJson, authHeaders } from './lib/http.js';
import { createApiHandleSummary } from './lib/summary.js';

// -- 설정 --
const PEAK_VUS = parseInt(__ENV.PEAK_VUS || '100', 10);
const WARMUP_VUS = Math.max(2, Math.floor(PEAK_VUS * 0.1));

// 각 단계 시간 (환경변수로 오버라이드 가능)
const WARMUP_DURATION = __ENV.WARMUP_DURATION || '1m';
const RAMPUP_DURATION = __ENV.RAMPUP_DURATION || '3m';
const PEAK_DURATION = __ENV.PEAK_DURATION || '5m';
const RAMPDOWN_DURATION = __ENV.RAMPDOWN_DURATION || '2m';
const COOLDOWN_DURATION = __ENV.COOLDOWN_DURATION || '2m';

const resumeBytes = open('../fixtures/resume.pdf', 'b');

function randomThink() {
  const base = thinkTimeMs();
  return (base * (0.5 + Math.random())) / 1000;
}

function kstNow() {
  const d = new Date(Date.now() + 9 * 3600 * 1000);
  return d.toISOString().replace('T', ' ').substring(0, 19);
}

// -- custom metrics --
const reqErrors = new Counter('req_errors');
const reqLatency = new Trend('req_latency', true);
const errorRate = new Rate('error_rate');

// -- k6 options --
export const options = {
  scenarios: {
    asg_scaling: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        // 1) Warm-up
        { duration: WARMUP_DURATION, target: WARMUP_VUS },
        // 2) Ramp-up
        { duration: RAMPUP_DURATION, target: PEAK_VUS },
        // 3) Peak
        { duration: PEAK_DURATION, target: PEAK_VUS },
        // 4) Ramp-down
        { duration: RAMPDOWN_DURATION, target: WARMUP_VUS },
        // 5) Cool-down
        { duration: COOLDOWN_DURATION, target: WARMUP_VUS },
      ],
      gracefulRampDown: '30s',
    },
  },

  systemTags: ['status', 'method', 'name', 'group', 'scenario'],
  summaryTrendStats: ['count', 'avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],

  thresholds: {
    'http_req_duration{api:health}': ['max>=0'],
    'http_req_duration{api:job-postings.list}': ['max>=0'],
    'http_req_duration{api:job-postings.analyze}': ['max>=0'],
    'http_req_duration{api:applications.apply}': ['max>=0'],
    'http_req_failed{api:health}': ['rate>=0'],
    'http_req_failed{api:job-postings.list}': ['rate>=0'],
    'http_req_failed{api:job-postings.analyze}': ['rate>=0'],
    'http_req_failed{api:applications.apply}': ['rate>=0'],
  },
};

const apis = [
  'health',
  'job-postings.list',
  'job-postings.analyze',
  'applications.apply',
];

export const handleSummary = createApiHandleSummary(apis);

export function setup() {
  console.log(`[${kstNow()}] === ASG Scaling Test ===`);
  console.log(`  PEAK_VUS=${PEAK_VUS}, WARMUP_VUS=${WARMUP_VUS}`);
  console.log(`  stages: warm-up(${WARMUP_DURATION}) → ramp-up(${RAMPUP_DURATION}) → peak(${PEAK_DURATION}) → ramp-down(${RAMPDOWN_DURATION}) → cool-down(${COOLDOWN_DURATION})`);
  return getTokenOrRefresh();
}

export function teardown() {
  console.log(`[${kstNow()}] === ASG Scaling Test finished ===`);
}

function logError(api, status, vuId, iter) {
  console.error(`[${kstNow()}] ERROR ${api} status=${status} vu=${vuId} iter=${iter}`);
}

function trackResult(api, res) {
  reqLatency.add(res.timings.duration);
  const ok = check(res, {
    [`${api} status 200`]: (r) => r.status === 200,
  });
  if (!ok) {
    reqErrors.add(1);
    errorRate.add(1);
    logError(api, res.status, __VU, __ITER);
  } else {
    errorRate.add(0);
  }
  return ok;
}

// -- 메인 시나리오 --
export default function (data) {
  const baseUrl = getBaseUrl();
  const token = pickTokenForVu(data);

  // 1) Health check — ALB가 인스턴스를 인식하는지 확인
  group('health', () => {
    const res = http.get(`${baseUrl}/api/health`, {
      tags: { api: 'health', name: 'health' },
    });
    trackResult('health', res);
  });

  sleep(randomThink());

  // 2) 공고 목록 조회 (읽기)
  group('read', () => {
    const page = Math.floor(Math.random() * 5);
    const res = getJson(
      `${baseUrl}/api/v1/job-postings?size=20&page=${page}&status=OPEN&sort=DEADLINE_ASC`,
      {
        ...authHeaders(token),
        tags: { api: 'job-postings.list', name: 'job-postings.list' },
      }
    );
    trackResult('job-postings.list', res);
  });

  sleep(randomThink());

  // 3) 공고 분석 (쓰기 — AI stub 사용)
  group('write-analyze', () => {
    const uniqueUrl = `https://example.com/jobs/asg-test/k6-${__VU}-${__ITER}-${Date.now()}`;
    const res = postJson(
      `${baseUrl}/api/v1/job-postings`,
      { url: uniqueUrl },
      {
        ...authHeaders(token),
        tags: { api: 'job-postings.analyze', name: 'job-postings.analyze' },
      }
    );
    const ok = trackResult('job-postings.analyze', res);

    // 분석 성공 시 지원서 제출
    if (ok) {
      const jobMasterId = res.json()?.data?.jobMasterId;
      if (jobMasterId) {
        sleep(randomThink());

        const formData = {
          jobPostingId: String(jobMasterId),
          resume: http.file(resumeBytes, `resume-${__VU}-${__ITER}.pdf`, 'application/pdf'),
        };

        const applyRes = http.post(`${baseUrl}/api/v1/applications`, formData, {
          headers: { Authorization: `Bearer ${token}` },
          tags: { api: 'applications.apply', name: 'applications.apply' },
        });
        trackResult('applications.apply', applyRes);
      }
    }
  });

  sleep(randomThink());
}
