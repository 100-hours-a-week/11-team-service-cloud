import http from 'k6/http';
import { sleep } from 'k6';
import { check } from 'k6';

import { getBaseUrl, thinkTimeMs } from '../lib/config.js';
import { postJson, authHeaders, expectStatusIn } from '../lib/http.js';

// apply -> evaluation 요청 -> 결과 조회(짧게 polling)
export function applyAndEvaluate(accessToken, jobMasterId, resumeBytes, portfolioBytes) {
  const baseUrl = getBaseUrl();

  // 1) 지원서 제출 (multipart)
  const formData = {
    jobPostingId: String(jobMasterId),
    resume: http.file(resumeBytes, `resume-${__VU}-${__ITER}.pdf`, 'application/pdf'),
  };
  if (portfolioBytes) {
    formData.portfolio = http.file(portfolioBytes, `portfolio-${__VU}-${__ITER}.pdf`, 'application/pdf');
  }

  const applyRes = http.post(`${baseUrl}/api/v1/applications`, formData, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
    tags: { name: 'applications.apply' },
  });

  // ApiResponse<Long>
  const applyOk = check(applyRes, {
    'applications.apply status 200': (r) => r.status === 200,
  });
  if (!applyOk) return null;

  const applyBody = applyRes.json();
  const applicationId = applyBody?.data;

  sleep(thinkTimeMs() / 1000);

  // 2) AI 평가 요청 (EVALUATION)
  const reqRes = postJson(
    `${baseUrl}/api/v1/applications/${applicationId}/analyses`,
    { analysis_type: 'EVALUATION' },
    authHeaders(accessToken)
  );
  // 컨트롤러에서 202 리턴
  expectStatusIn(reqRes, [202, 200], 'applications.request-analyses');

  sleep(thinkTimeMs() / 1000);

  // 3) 결과 polling (AI worker가 stub로 매우 빠르게 끝난다는 가정)
  // 아직 준비가 안 됐으면 202/500 등 다양할 수 있어서, 짧게만 시도
  const maxAttempts = parseInt(__ENV.EVAL_POLL_ATTEMPTS || '5', 10);
  const intervalMs = parseInt(__ENV.EVAL_POLL_INTERVAL_MS || '500', 10);

  for (let i = 0; i < maxAttempts; i++) {
    const res = http.get(`${baseUrl}/api/v1/applications/${applicationId}/analyses`, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
      tags: { name: 'applications.get-analysis' },
    });

    if (res.status === 200) {                                                    
      const body = res.json();                                                        
      const overall = body?.data?.overallScore;                                                                          
                                                                                                                            
      const hasScore = overall !== undefined && overall !== null;                                                            
                                                                                                                            
      check(body, {                                                                                                          
        'analysis has overallScore': () => hasScore,                                                                         
      });                                                                                                                    
                                                                                                                            
      if (hasScore) {                                                                                                        
        break;                                                                                            
      }                                                    
    } 

    sleep(intervalMs / 1000);
  }

  return applicationId;
}
