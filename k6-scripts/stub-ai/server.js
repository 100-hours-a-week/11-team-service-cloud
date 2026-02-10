// Minimal AI stub server (no dependencies)
// Purpose: avoid paid AI API calls during load tests.
//
// Spring BE expects ai.service.url +
//  - POST /ai/api/v1/job-posting/analyze   (AiJobAnalysisRequest)
//  - DELETE /ai/api/v1/job-posting/:id
//  - POST /ai/api/v1/applicant/evaluate    (AiEvaluationAnalysisRequest)
// and returns AiApiResponse<T>
//
// Usage:
//  node stub-ai/server.js
//  PORT=9010 node stub-ai/server.js
//  AI_STUB_SEED=1 node stub-ai/server.js
//
// Then run BE with: ai.service.url=http://127.0.0.1:9010

import http from 'node:http';

const PORT = parseInt(process.env.PORT || '9010', 10);
const SEED = parseInt(process.env.AI_STUB_SEED || '1', 10);

function nowIso() {
  return new Date().toISOString();
}

function sendJson(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

function ok(data) {
  return {
    success: true,
    timestamp: nowIso(),
    data,
    error: null,
  };
}

function stableIdFromString(s) {
  // cheap deterministic hash -> positive int
  let h = 2166136261 + SEED;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return Math.abs(h % 1000000000) + 1;
}

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (chunk) => {
      data += chunk;
      if (data.length > 2_000_000) {
        reject(new Error('body too large'));
        req.destroy();
      }
    });
    req.on('end', () => {
      if (!data) return resolve(null);
      try {
        resolve(JSON.parse(data));
      } catch (e) {
        resolve(null);
      }
    });
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  if (req.method === 'POST' && url.pathname === '/ai/api/v1/job-posting/analyze') {
    const body = await parseBody(req);
    const sourceUrl = body?.url || 'unknown';
    const id = stableIdFromString(sourceUrl);

    return sendJson(res, 200, ok({
      job_posting_id: id,
      is_existing: false,
      company_name: 'K6 Stub Company',
      job_title: `Backend Engineer (stub-${id})`,
      main_responsibilities: [
        'Design REST APIs',
        'Implement Spring services',
        'Optimize DB queries'
      ],
      required_skills: ['Java', 'Spring', 'MySQL', 'AWS'],
      recruitment_status: 'OPEN',
      recruitment_period: {
        start_date: '2026-01-01',
        end_date: '2026-12-31'
      },
      ai_summary: 'This is a stub summary (no paid AI call).',
      evaluation_criteria: [
        { name: 'Problem Solving', description: 'Ability to break down problems.' },
        { name: 'Backend Fundamentals', description: 'HTTP, DB, concurrency.' }
      ]
    }));
  }

  if (req.method === 'DELETE' && url.pathname.startsWith('/ai/api/v1/job-posting/')) {
    // BE ignores body, best-effort delete.
    res.writeHead(204);
    return res.end();
  }

  if (req.method === 'POST' && url.pathname === '/ai/api/v1/applicant/evaluate') {
    const body = await parseBody(req);
    const key = `${body?.user_id || 'u'}:${body?.job_posting_id || 'j'}`;
    const id = stableIdFromString(key);

    // AiEvaluationResultResponse (infra dto) uses snake_case properties
    return sendJson(res, 200, ok({
      overall_score: 72 + (id % 28),
      competency_scores: [
        { name: 'Resume', score: 80, description: 'Stub resume score.' },
        { name: 'Portfolio', score: 75, description: 'Stub portfolio score.' },
        { name: 'Fit', score: 78, description: 'Stub fit score.' }
      ],
      one_line_review: 'Stub evaluation: decent match.',
      feedback_detail: 'This evaluation is produced by stub-ai to avoid API cost.',
      evaluation_criteria: [
        { name: 'Communication', description: 'Clear writing and structure.' },
        { name: 'Experience', description: 'Relevant backend experience.' }
      ]
    }));
  }

  sendJson(res, 404, { message: 'not found', path: url.pathname });
});

server.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`[stub-ai] listening on http://127.0.0.1:${PORT}`);
});
