import { sleep } from 'k6';
import { check } from 'k6';

import { getBaseUrl, thinkTimeMs } from '../lib/config.js';
import { getJson, expectStatus } from '../lib/http.js';

export function browseJobPostings() {
  const baseUrl = getBaseUrl();

  const listRes = getJson(`${baseUrl}/api/v1/job-postings?size=20&status=OPEN&sort=DEADLINE_ASC`, {
    tags: { api: 'job-postings.list', name: 'job-postings.list' },
  });
  expectStatus(listRes, 200, 'job-postings.list');

  const listBody = listRes.json();
  // ApiResponse<Map<String,Object>> 형태라 구조가 유동적
  // 다만 data 안에 items/list 류가 있을 수 있으니 존재성만 체크
  check(listBody, {
    'list response has data': (b) => !!b && b.data !== undefined,
  });

  sleep(thinkTimeMs() / 1000);
}
