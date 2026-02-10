function pickMetric(data, key) {
  return data?.metrics?.[key]?.values || null;
}

function fmtMs(v) {
  if (v === null || v === undefined || Number.isNaN(v)) return '-';
  return `${v.toFixed(2)}ms`;
}

function fmtPct(v) {
  if (v === null || v === undefined || Number.isNaN(v)) return '-';
  return `${(v * 100).toFixed(2)}%`;
}

function fmtNum(v, digits = 2) {
  if (v === null || v === undefined || Number.isNaN(v)) return '-';
  return v.toFixed(digits);
}

// Fallback failure-rate from k6 "checks" metric.
// We aggregate all checks whose name starts with "<api> ", because our check labels are like:
//   "chat.send-message status in [201,200]"
//   "job-postings.analyze status 200"
function inferFailRateFromChecks(data, api) {
  const metrics = data?.metrics || {};
  const prefix = `${api} `;

  let passes = 0;
  let fails = 0;
  let matched = false;

  for (const key of Object.keys(metrics)) {
    // Example key in summary:
    //   checks{check:chat.send-message status in [201,200]}
    if (!key.startsWith('checks{check:')) continue;

    const checkName = key.slice('checks{check:'.length, -1); // remove prefix and trailing "}"
    if (!checkName.startsWith(prefix)) continue;

    const v = metrics[key]?.values;
    if (!v) continue;

    // In k6, checks metric values commonly include passes/fails.
    if (typeof v.passes === 'number') passes += v.passes;
    if (typeof v.fails === 'number') fails += v.fails;
    matched = true;
  }

  if (!matched) return null;
  const total = passes + fails;
  if (total === 0) return null;
  return fails / total;
}

/**
 * Create a k6 handleSummary() that prints API-tag breakdown to stdout.
 *
 * Requirements:
 * - Each request should include tags: { api: '<name>' }
 *
 * Output columns:
 * api | count | rps | fail | p(90) | p(95) | p(99) | max
 */
export function createApiHandleSummary(apis) {
  return function handleSummary(data) {
    const runMs = data?.state?.testRunDurationMs;
    const runSec = runMs ? runMs / 1000 : null;

    const lines = [];
    lines.push('');
    lines.push('=== API breakdown (tag: api) ===');
    lines.push('api | count | rps | fail | p(90) | p(95) | p(99) | max');
    lines.push('---|---:|---:|---:|---:|---:|---:|---:');

    for (const api of apis) {
      const dur = pickMetric(data, `http_req_duration{api:${api}}`);
      const fail = pickMetric(data, `http_req_failed{api:${api}}`);
      const reqs = pickMetric(data, `http_reqs{api:${api}}`);

      // Some k6 output setups don't keep tag-breakdowns for counters in summary.
      // Trend.count is a reliable fallback.
      const count = (reqs?.count ?? dur?.count ?? 0);
      const rps = reqs?.rate ?? (runSec ? count / runSec : null);

      // Prefer k6 built-in http_req_failed; if missing, fall back to check failures.
      const failRate = fail?.rate ?? inferFailRateFromChecks(data, api);

      lines.push(
        [
          api,
          String(count),
          fmtNum(rps, 2),
          fmtPct(failRate),
          fmtMs(dur?.['p(90)']),
          fmtMs(dur?.['p(95)']),
          fmtMs(dur?.['p(99)']),
          fmtMs(dur?.max),
        ].join(' | ')
      );
    }

    lines.push('');

    return { stdout: lines.join('\n') };
  };
}
