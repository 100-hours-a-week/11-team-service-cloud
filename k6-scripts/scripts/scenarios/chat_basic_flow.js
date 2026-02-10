import http from 'k6/http';
import { sleep } from 'k6';
import { check } from 'k6';

import { getBaseUrl, thinkTimeMs } from '../lib/config.js';
import { postJson, getJson, expectStatusIn, authHeaders } from '../lib/http.js';

// 단일 유저 기준 기본 채팅 플로우:
// 1) 채팅방 생성 (공고별)
// 2) 채팅방 입장
// 3) 텍스트 메시지 전송 (multipart/form-data)
// 4) 메시지 목록 조회
// 5) 멤버 목록 조회
export function chatBasicFlow(accessToken, jobMasterId) {
  const baseUrl = getBaseUrl();

  // 1) 채팅방 생성
  const roomName = `k6-room-${__VU}-${__ITER}`;
  const roomGoal = (__ENV.ROOM_GOAL || 'INTERVIEW').trim();                                                              
  const maxParticipants = parseInt(__ENV.MAX_PARTICIPANTS || '4', 10);         
  const cutlineScore = parseInt(__ENV.CUTLINE_SCORE || '70', 10);              

  const createRes = postJson(
    `${baseUrl}/api/v1/job-postings/${jobMasterId}/chat-rooms`,
    { roomName, roomGoal, maxParticipants, cutlineScore },
    {
      ...authHeaders(accessToken),
      tags: { api: 'chat.create-room', name: 'chat.create-room' },
    }
  );
  expectStatusIn(createRes, [201, 200], 'chat.create-room');

  const createBody = createRes.json();
  // API 응답의 data가 number일 수도, object일 수도 있어서 방어적으로 추출   
  const data = createBody?.data;                                             
  const chatRoomId =                                                         
    (typeof data === 'number' || typeof data === 'string')                   
      ? data                                                                 
      : (data?.chatRoomId ?? data?.id ?? data?.roomId ?? null);              

  check(createBody, {                                                        
    'create-room has roomId': () => !!chatRoomId,                            
  });                                                                        

  if (!chatRoomId) return null;                                       

  sleep(thinkTimeMs() / 1000);

  // 2) 채팅방 입장
  const joinRes = http.post(
    `${baseUrl}/api/v1/chat-rooms/${chatRoomId}/members`,
    '',
    {
      headers: { Authorization: `Bearer ${accessToken}` },
      tags: { api: 'chat.join-room', name: 'chat.join-room' },
      // 이 API는 이미 참가한 경우 409가 "정상"일 수 있어 k6의 expected_response 판단을 확장
      responseCallback: http.expectedStatuses(200, 201, 409),
    }
  );
  expectStatusIn(joinRes, [200, 201, 409], 'chat.join-room');

  sleep(thinkTimeMs() / 1000);

  // 3) 메시지 전송 (multipart/form-data)
  const content = `hello from k6 (vu=${__VU} iter=${__ITER})`;
  // 빈 파일(0바이트) 하나를 multipart 트리거용으로 넣음                                                                       
  const dummy = http.file('', `dummy-${__VU}-${__ITER}.txt`, 'text/plain');
  const msgForm = {
    messageType: 'TEXT',
    content,
    file: dummy,
  };

  const sendRes = http.post(`${baseUrl}/api/v1/chat-rooms/${chatRoomId}/messages`, msgForm, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
    tags: { api: 'chat.send-message', name: 'chat.send-message' },
  });

  expectStatusIn(sendRes, [201, 200], 'chat.send-message');

  sleep(thinkTimeMs() / 1000);

  // 4) 메시지 목록
  const listRes = getJson(`${baseUrl}/api/v1/chat-rooms/${chatRoomId}/messages?size=50`, {
    headers: { Authorization: `Bearer ${accessToken}` },
    tags: { api: 'chat.list-messages', name: 'chat.list-messages' },
  });
  expectStatusIn(listRes, [200], 'chat.list-messages');

  sleep(thinkTimeMs() / 1000);

  // 5) 멤버 목록
  const membersRes = getJson(`${baseUrl}/api/v1/chat-rooms/${chatRoomId}/members`, {
    headers: { Authorization: `Bearer ${accessToken}` },
    tags: { api: 'chat.list-members', name: 'chat.list-members' },
  });
  expectStatusIn(membersRes, [200], 'chat.list-members');

  sleep(thinkTimeMs() / 1000);
  return chatRoomId;
}
