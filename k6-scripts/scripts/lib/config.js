import { fail } from 'k6';

export function getBaseUrl() {
  const base = (__ENV.TARGET_BASE_URL || '').trim();
  if (!base) fail('TARGET_BASE_URL env is required (e.g. http://127.0.0.1:8080)');
  return base.replace(/\/$/, '');
}

export function getAccessToken() {
  return (__ENV.ACCESS_TOKEN || '').trim();
}

export function getRefreshToken() {
  return (__ENV.REFRESH_TOKEN || '').trim();
}

export function vus() {
  return parseInt(__ENV.VUS || '10', 10);
}

export function duration() {
  return (__ENV.DURATION || '30s').trim();
}

export function thinkTimeMs() {
  return parseInt(__ENV.THINK_TIME_MS || '200', 10);
}

export function debug() {
  return (__ENV.DEBUG || '').toLowerCase() === 'true';
}
