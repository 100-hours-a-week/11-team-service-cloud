import http from 'k6/http';
import { sleep } from 'k6';
import { getBaseUrl, getAccessToken, getRefreshToken, thinkTimeMs } from './config.js';
import { postJson, authHeaders, expectStatus, expectStatusIn } from './http.js';

function parseTokenPoolEnv() {
  const raw = (__ENV.ACCESS_TOKENS || '').trim();
  if (!raw) return [];
  return raw
    .split(',')
    .map((t) => t.trim())
    .filter((t) => t.length > 0);
}

function getLoadtestSecret() {
  return (__ENV.LOADTEST_SECRET || '').trim();
}

function getTokenCountHint() {
  // 기본: VUS 값 만큼 토큰 발급
  const v = parseInt(__ENV.VUS || '10', 10);
  return parseInt(__ENV.TOKEN_COUNT || String(v), 10);
}

// OAuth(카카오) 자체를 k6로 자동화하는 건(브라우저/인증 UI) 비용이 큼.
// 부하테스트에서는 '사전에 발급해 둔' refreshToken 또는 accessToken을 ENV로 주입해서 사용.
//
// 토큰 전략:
// 1) ACCESS_TOKENS=token1,token2,...  (VU별로 분배해서 사용)
// 2) REFRESH_TOKEN이 있으면 /api/v1/auth/kakao/refresh로 accessToken을 setup에서 갱신
// 3) 그 외 ACCESS_TOKEN 단일 사용
export function getTokenOrRefresh() {
  const pool = parseTokenPoolEnv();
  if (pool.length > 0) {
    return { accessToken: '', refreshToken: '', accessTokens: pool };
  }

  // loadtest 전용 토큰 배치 발급 (X-Test-Secret)
  const loadtestSecret = getLoadtestSecret();
  if (loadtestSecret) {
    const baseUrl = getBaseUrl();
    const count = getTokenCountHint();

    const res = http.get(`${baseUrl}/api/v1/auth/test/tokens?count=${count}`, {
      headers: { 'X-Test-Secret': loadtestSecret },
      tags: { name: 'auth.loadtest.tokens' },
    });

    expectStatusIn(res, [200], 'auth.loadtest.tokens');
    const body = res.json();
    const tokens = body?.data?.tokens || [];
    const accessTokens = tokens
      .map((t) => t?.accessToken)
      .filter((t) => typeof t === 'string' && t.length > 0);

    if (accessTokens.length === 0) {
      return { accessToken: '', refreshToken: '', accessTokens: [] };
    }

    return { accessToken: '', refreshToken: '', accessTokens };
  }

  const baseUrl = getBaseUrl();
  const refreshToken = getRefreshToken();
  const accessToken = getAccessToken();

  if (refreshToken) {
    const res = postJson(
      `${baseUrl}/api/v1/auth/kakao/refresh`,
      { refreshToken },
      authHeaders('')
    );
    expectStatus(res, 200, 'auth.refresh');
    const body = res.json();
    // TokenRefreshResponse: { accessToken, refreshToken, expiresIn, tokenType }
    const newAccess = body?.accessToken;
    const newRefresh = body?.refreshToken;
    if (!newAccess) return { accessToken: accessToken, refreshToken };

    sleep(thinkTimeMs() / 1000);
    return { accessToken: newAccess, refreshToken: newRefresh || refreshToken };
  }

  return { accessToken, refreshToken: '' };
}

export function pickTokenForVu(setupData) {
  if (setupData?.accessTokens?.length) {
    // __VU는 1부터 시작
    const idx = (__VU - 1) % setupData.accessTokens.length;
    return setupData.accessTokens[idx];
  }
  return setupData?.accessToken || '';
}
