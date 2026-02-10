import { sleep } from 'k6';
import { check } from 'k6';

import { getBaseUrl, thinkTimeMs } from '../lib/config.js';
import { postJson, patchJson, authHeaders, expectStatus } from '../lib/http.js';

export function analyzeAndConfirm(accessToken) {
  const baseUrl = getBaseUrl();

  // JobPostingAnalysisService.normalizeUrl()가 여러 파라미터를 제거하므로,
  // 제거 리스트에 없는 k6 파라미터로 유니크 URL을 만든다.
  const uniqueUrl = `https://example.com/jobs/backend/k6-${__VU}-${__ITER}-${Date.now()}`;

  const analyzeRes = postJson(
    `${baseUrl}/api/v1/job-postings`,
    { url: uniqueUrl },
    {
      ...authHeaders(accessToken),
      tags: { api: 'job-postings.analyze', name: 'job-postings.analyze' },
    }
  );
  const ok = expectStatus(analyzeRes, 200, 'job-postings.analyze');
  if (!ok) return null;

  const analyzeBody = analyzeRes.json();
  check(analyzeBody, {
    'analyze response has data': (b) => !!b && !!b.data,
    'analyze response has jobMasterId': (b) => !!b?.data?.jobMasterId,
  });

  const jobMasterId = analyzeBody.data.jobMasterId;

  sleep(thinkTimeMs() / 1000);

  // confirm(등록)까지 포함하면 DB write가 늘어서 실제 부하에 가까움
  // registrationStatus enum: DRAFT -> REGISTERED 로 추정
  const confirmRes = patchJson(
    `${baseUrl}/api/v1/job-postings/${jobMasterId}`,
    { registrationStatus: 'CONFIRMED' },
    {
      ...authHeaders(accessToken),
      tags: { api: 'job-postings.confirm', name: 'job-postings.confirm' },
    }
  );
  // 성공(200) 또는 이미 등록된 경우(200) 기대
  expectStatus(confirmRes, 200, 'job-postings.confirm');

  sleep(thinkTimeMs() / 1000);
  return jobMasterId;
}
