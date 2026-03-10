import http from 'k6/http';
import { check } from 'k6';

export function authHeaders(accessToken, extra = {}) {
  const headers = {
    'Content-Type': 'application/json',
    ...extra,
  };
  if (accessToken) headers['Authorization'] = `Bearer ${accessToken}`;
  return { headers };
}

export function expectStatus(res, expected, label) {
  const ok = check(res, {
    [`${label} status ${expected}`]: (r) => r && r.status === expected,
  });
  return ok;
}

export function expectStatusIn(res, expectedList, label) {
  const ok = check(res, {
    [`${label} status in [${expectedList.join(',')}]`]: (r) => r && expectedList.includes(r.status),
  });
  return ok;
}

export function getJson(url, params) {
  return http.get(url, params);
}

export function postJson(url, body, params) {
  return http.post(url, JSON.stringify(body), params);
}

export function patchJson(url, body, params) {
  return http.patch(url, JSON.stringify(body), params);
}
