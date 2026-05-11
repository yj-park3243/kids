# API 정의서

## Base URL

```
https://api.example.com/v1
```

## 공통 사항

### 인증 헤더

```
Authorization: Bearer {accessToken}
```

### 공통 응답 구조

> 본 문서의 모든 라우트 응답은 별도 명시가 없는 한 아래 wrapping 규약을 따른다.
> 즉, 이후 예제의 응답 JSON은 모두 `data` 필드 내부에 들어간다고 가정한다.
> (예외: `POST /auth/kcp/callback` 의 HTML redirect 응답)

```json
// 성공
{
  "success": true,
  "data": { ... }
}

// 에러
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "에러 메시지"
  }
}
```

### JWT 토큰 구조

| 토큰 | 용도 | 만료 | Payload |
|------|------|------|---------|
| accessToken | 보호 라우트 인증 | 1시간 | `{ sub, email, isAdmin, type: "access", iss: "kids-app", jti, iat, exp }` |
| refreshToken | accessToken 재발급 전용 | 14일 | `{ sub, email, isAdmin, type: "refresh", iss: "kids-app", jti, iat, exp }` |

**검증 정책**

- 모든 보호 라우트는 `type === "access"` 와 `iss === "kids-app"` 을 강제 검증한다.
- refreshToken 으로 보호 라우트를 호출하면 `401 UNAUTHORIZED` 를 반환한다.
- refreshToken 은 `POST /auth/refresh` 에서만 허용된다.

### 공통 에러 코드

| HTTP | 코드 | 설명 |
|------|------|------|
| 400 | BAD_REQUEST | 잘못된 요청 |
| 401 | UNAUTHORIZED | 인증 필요 |
| 403 | FORBIDDEN | 권한 없음 |
| 404 | NOT_FOUND | 리소스 없음 |
| 409 | CONFLICT | 중복/충돌 |
| 422 | VALIDATION_ERROR | 유효성 검사 실패 |
| 500 | INTERNAL_ERROR | 서버 오류 |

### 페이징 응답

```json
{
  "success": true,
  "data": {
    "items": [...],
    "nextCursor": "string | null",
    "hasMore": true
  }
}
```

---

## 1. Auth API

### POST /auth/social

소셜 로그인 (카카오, Apple, Google 통합)

**Request**

```json
{
  "provider": "KAKAO | APPLE | GOOGLE",
  "accessToken": "string",
  "idToken": "string | null"
}
```

> - 카카오: `accessToken` 사용
> - Apple: `idToken` 사용
> - Google: `idToken` 사용

**Response 200** (기존 유저)

```json
{
  "accessToken": "string",
  "refreshToken": "string",
  "user": { ... },
  "isNewUser": false
}
```

**Response 200** (신규 유저)

```json
{
  "accessToken": "string",
  "refreshToken": "string",
  "user": { "id": "uuid" },
  "isNewUser": true
}
```

### POST /auth/email/register

이메일 회원가입

**Request**

```json
{
  "email": "string",
  "password": "string (8자 이상, 영문+숫자+특수문자)"
}
```

**Response 201**

```json
{
  "accessToken": "string",
  "refreshToken": "string",
  "user": { "id": "uuid", "email": "string" },
  "isNewUser": true
}
```

**Error**

| 코드 | 상황 |
|------|------|
| 409 EMAIL_ALREADY_EXISTS | 이메일 중복 |
| 422 WEAK_PASSWORD | 비밀번호 조건 미충족 |

### POST /auth/email/login

이메일 로그인

**Request**

```json
{
  "email": "string",
  "password": "string"
}
```

**Response 200**

```json
{
  "accessToken": "string",
  "refreshToken": "string",
  "user": { ... },
  "isNewUser": false
}
```

**Error**

| 코드 | 상황 |
|------|------|
| 401 INVALID_CREDENTIALS | 이메일/비밀번호 불일치 |

### POST /auth/refresh

토큰 재발급

**Request**

```json
{
  "refreshToken": "string"
}
```

**Response 200**

```json
{
  "accessToken": "string",
  "refreshToken": "string"
}
```

### POST /auth/logout

로그아웃 `[인증필요]`

**Response 200**

```json
{
  "success": true
}
```

### POST /auth/phone/verify

핸드폰 본인 인증 `[인증필요]`

`code` 없이 호출하면 인증번호 발송, 포함해 호출하면 검증 수행.

**Request (발송)**

```json
{
  "phoneNumber": "01012345678"
}
```

**Response 200 (발송)**

```json
{
  "sent": true,
  "expiresInSeconds": 180
}
```

**Request (검증)**

```json
{
  "phoneNumber": "01012345678",
  "code": "123456"
}
```

**Response 200 (검증)**

```json
{
  "verified": true,
  "phoneNumber": "010-****-5678"
}
```

**Error**

| 코드 | 상황 |
|------|------|
| 400 VERIFICATION_NOT_REQUESTED | 발송 없이 검증 요청 |
| 400 VERIFICATION_EXPIRED | 인증번호 만료(3분) |
| 400 VERIFICATION_MISMATCH | 인증번호 불일치 |
| 409 PHONE_ALREADY_USED | 이미 다른 계정이 사용 중 |

> 실제 SMS 발송은 외부 서비스(NHN Cloud SMS / Naver Cloud SENS / CoolSMS 등) 연동 필요.

### GET /auth/kcp/form

KCP 본인인증 진입 폼(HTML) 발급 `[인증필요]`

> 앱이 WebView 로 띄울 KCP 표준창 진입 form 을 서버가 서명·생성해서 내려준다.
> 클라이언트는 받은 HTML 을 WebView 에 로드만 하면 KCP 측으로 자동 제출된다.

**Response 200**

```json
{
  "html": "<form ...>...</form><script>document.forms[0].submit()</script>"
}
```

### POST /auth/kcp/callback

KCP 인증 완료 콜백 (Public, 외부 KCP 서버가 호출)

> 본 라우트는 앱이 직접 호출하지 않는다. KCP 인증 완료 후 KCP 측이 서버로 결과를
> `application/x-www-form-urlencoded` 로 POST 하며, 서버는 검증 후 앱 딥링크로 redirect 하는
> HTML 을 응답한다. 클라이언트(WebView)는 이 redirect 로 인해 `kids://kcp-cert?...` 스킴이 호출되어
> 앱으로 돌아온다.

**Request (form-urlencoded, KCP 표준 필드)**

```
cert_no=...&dn=...&ordr_idxx=...&...
```

**Response 200** — `Content-Type: text/html`

```html
<!doctype html>
<html><head>
  <meta http-equiv="refresh" content="0;url=kids://kcp-cert?status=ok&ci=...&name=...&phoneNumber=...">
</head><body>processing...</body></html>
```

| 결과 | 딥링크 쿼리 |
|------|-------------|
| 성공 | `kids://kcp-cert?status=ok&ci={ci}&name={name}&phoneNumber={phone}` |
| 실패/취소 | `kids://kcp-cert?status=fail&reason={reason}` |

---

## 2. User API

### POST /users/profile

프로필 초기 설정 (회원가입 완료) `[인증필요]`

**Request**

```json
{
  "nickname": "string (2~10자)",
  "regionSido": "string",
  "regionSigungu": "string",
  "regionDong": "string",
  "profileImageUrl": "string | null",
  "introduction": "string | null"
}
```

**Response 201**

```json
{
  "id": "uuid",
  "nickname": "string",
  "regionSido": "string",
  "regionSigungu": "string",
  "regionDong": "string",
  "profileImageUrl": "string | null",
  "introduction": "string | null",
  "createdAt": "ISO8601"
}
```

### GET /users/me

내 프로필 조회 `[인증필요]`

### PATCH /users/me

내 프로필 수정 `[인증필요]`

**Request** (변경할 필드만 전송)

```json
{
  "nickname": "string",
  "regionDong": "string",
  "profileImageUrl": "string",
  "introduction": "string"
}
```

### GET /users/check-nickname?nickname={nickname}

닉네임 중복 체크 `[인증필요]`

**Response 200**

```json
{
  "available": true
}
```

### GET /users/:userId

다른 유저 프로필 조회 `[인증필요]`

**Response 200**

```json
{
  "id": "uuid",
  "nickname": "string",
  "regionSigungu": "string",
  "profileImageUrl": "string | null",
  "introduction": "string | null",
  "children": [
    {
      "nickname": "string",
      "ageMonths": 12,
      "gender": "MALE | FEMALE | null"
    }
  ],
  "roomCount": 15,
  "createdAt": "ISO8601"
}
```

### DELETE /users/me

회원 탈퇴 `[인증필요]`

**Request**

```json
{
  "reason": "string | null"
}
```

---

## 3. Children API

### POST /children

아이 등록 `[인증필요]`

**Request**

```json
{
  "nickname": "string (1~10자)",
  "birthYear": 2024,
  "birthMonth": 6,
  "gender": "MALE | FEMALE | null"
}
```

**Response 201**

```json
{
  "id": "uuid",
  "nickname": "string",
  "birthYear": 2024,
  "birthMonth": 6,
  "ageMonths": 10,
  "gender": "MALE | null",
  "createdAt": "ISO8601"
}
```

### GET /children

내 아이 목록 조회 `[인증필요]`

### PATCH /children/:childId

아이 정보 수정 `[인증필요]`

### DELETE /children/:childId

아이 정보 삭제 `[인증필요]` (최소 1명은 유지)

---

## 4. Room API

### POST /rooms

방 생성 `[인증필요]`

**Request**

```json
{
  "title": "string (2~30자)",
  "description": "string (10~500자)",
  "regionSido": "string",
  "regionSigungu": "string",
  "regionDong": "string",
  "date": "2026-04-15",
  "startTime": "14:00",
  "endTime": "16:00 | null",
  "ageMonthMin": 6,
  "ageMonthMax": 12,
  "placeType": "PLAYGROUND | KIDS_CAFE | PARTY_ROOM | PARK | OTHER",
  "placeName": "string | null",
  "placeAddress": "string | null",
  "latitude": "float | null (주소 입력 시 Geocoding 자동 변환)",
  "longitude": "float | null",
  "maxMembers": 5,
  "joinType": "FREE | APPROVAL",
  "cost": 0,
  "costDescription": "string | null",
  "tags": ["산책", "이유식"]
}
```

**Response 201**

```json
{
  "id": "uuid",
  "title": "string",
  "status": "RECRUITING",
  "host": { "id": "uuid", "nickname": "string", "profileImageUrl": "..." },
  "currentMembers": 1,
  "maxMembers": 5,
  "chatRoomId": "uuid",
  ...
}
```

### GET /rooms

방 목록 조회 `[인증필요]`

> **약속 날짜가 오늘 이전인 방은 자동 제외** (`WHERE date >= CURRENT_DATE`)

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| regionDong | string | X | 동 필터 (기본: 내 동네) |
| regionSigungu | string | X | 구 단위 확장 검색 |
| dateFrom | date | X | 시작 날짜 (기본: 오늘) |
| dateTo | date | X | 종료 날짜 |
| ageMonth | int | X | 개월수 (±3 범위 자동) |
| placeType | enum | X | 장소 유형 |
| joinType | enum | X | 입장 방식 |
| costFree | boolean | X | 무료만 |
| cursor | string | X | 페이징 커서 |
| limit | int | X | 페이지 크기 (기본 20) |

**Response 200**

```json
{
  "items": [
    {
      "id": "uuid",
      "title": "string",
      "date": "2026-04-15",
      "startTime": "14:00",
      "regionDong": "string",
      "ageMonthMin": 6,
      "ageMonthMax": 12,
      "placeType": "PLAYGROUND",
      "currentMembers": 3,
      "maxMembers": 5,
      "joinType": "FREE",
      "cost": 0,
      "tags": ["산책"],
      "status": "RECRUITING",
      "host": { "id": "uuid", "nickname": "string", "profileImageUrl": "..." },
      "latitude": 37.5012,
      "longitude": 127.0396
    }
  ],
  "nextCursor": "string | null",
  "hasMore": true
}
```

### GET /rooms/map

지도 뷰용 방 조회 (영역 기반) `[인증필요]`

> 화면에 보이는 지도 영역 내 방만 조회. 약속 날짜 지난 방 제외.

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| swLat | float | O | 남서쪽 위도 |
| swLng | float | O | 남서쪽 경도 |
| neLat | float | O | 북동쪽 위도 |
| neLng | float | O | 북동쪽 경도 |
| ageMonth | int | X | 개월수 필터 |
| zoomLevel | int | X | 현재 줌 레벨 (클러스터/핀 판단용) |

**Response 200** (줌 레벨 ~13: 클러스터 모드)

```json
{
  "mode": "CLUSTER",
  "clusters": [
    {
      "regionDong": "역삼동",
      "count": 8,
      "latitude": 37.5012,
      "longitude": 127.0396
    }
  ]
}
```

**Response 200** (줌 레벨 14~: 핀 모드)

```json
{
  "mode": "PIN",
  "pins": [
    {
      "id": "uuid",
      "title": "string",
      "date": "2026-04-15",
      "startTime": "14:00",
      "ageMonthMin": 6,
      "ageMonthMax": 12,
      "currentMembers": 3,
      "maxMembers": 5,
      "latitude": 37.5012,
      "longitude": 127.0396
    }
  ]
}
```

### GET /rooms/:roomId

방 상세 조회 `[인증필요]`

**Response 200**

```json
{
  "id": "uuid",
  "title": "string",
  "description": "string",
  "date": "2026-04-15",
  "startTime": "14:00",
  "endTime": "16:00",
  "regionSido": "서울특별시",
  "regionSigungu": "강남구",
  "regionDong": "역삼동",
  "ageMonthMin": 6,
  "ageMonthMax": 12,
  "placeType": "KIDS_CAFE",
  "placeName": "플레이존 키즈카페",
  "placeAddress": "서울 강남구 역삼동 123-45",
  "latitude": 37.5012,
  "longitude": 127.0396,
  "maxMembers": 5,
  "currentMembers": 3,
  "joinType": "APPROVAL",
  "cost": 5000,
  "costDescription": "키즈카페 입장료 더치페이",
  "tags": ["실내놀이", "10개월"],
  "status": "RECRUITING",
  "host": {
    "id": "uuid",
    "nickname": "콩이맘",
    "profileImageUrl": "...",
    "regionSigungu": "강남구"
  },
  "members": [
    {
      "id": "uuid",
      "nickname": "콩이맘",
      "profileImageUrl": "...",
      "children": [{ "nickname": "콩이", "ageMonths": 10, "gender": "MALE" }],
      "isHost": true
    }
  ],
  "myStatus": "NONE | PENDING | ACCEPTED | REJECTED",
  "canJoin": true,
  "canJoinReason": "string | null",
  "chatRoomId": "uuid",
  "createdAt": "ISO8601"
}
```

### PATCH /rooms/:roomId

방 수정 (방장) `[인증필요]`

**수정 가능 필드**: title, description, startTime, endTime, placeName, placeAddress, maxMembers, cost, costDescription, tags

**수정 불가**: date, region*, ageMonth*, placeType, joinType

### DELETE /rooms/:roomId

방 취소 (방장) `[인증필요]`

→ 상태를 CANCELLED로 변경, 참여자 전원에게 취소 알림

### GET /rooms/my

내 모임 목록 `[인증필요]`

**Query Parameters**

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| type | enum | HOSTING(내가 만든) / JOINED(참여한) / ALL |
| status | enum | UPCOMING(예정) / PAST(지난) |

---

## 5. Room Participation API

### POST /rooms/:roomId/join

참여 신청 `[인증필요]`

**Response 200** (자유 입장)

```json
{
  "status": "ACCEPTED",
  "chatRoomId": "uuid"
}
```

**Response 200** (승인 필요)

```json
{
  "status": "PENDING"
}
```

**Error 케이스**

| 코드 | 상황 |
|------|------|
| 409 ALREADY_JOINED | 이미 참여/신청 중 |
| 409 ROOM_FULL | 인원 초과 |
| 403 AGE_NOT_MATCH | 개월수 불일치 |
| 403 ROOM_NOT_RECRUITING | 모집 종료 |

### DELETE /rooms/:roomId/join

참여 취소 (본인) `[인증필요]`

### GET /rooms/:roomId/join-requests

참여 신청 목록 (방장) `[인증필요]`

**Response 200**

```json
{
  "items": [
    {
      "id": "uuid",
      "user": {
        "id": "uuid",
        "nickname": "string",
        "profileImageUrl": "...",
        "children": [{ "nickname": "...", "ageMonths": 8, "gender": "FEMALE" }]
      },
      "status": "PENDING",
      "createdAt": "ISO8601"
    }
  ]
}
```

### PATCH /rooms/:roomId/join-requests/:requestId

신청 수락/거절 (방장) `[인증필요]`

**Request**

```json
{
  "action": "ACCEPT | REJECT"
}
```

### DELETE /rooms/:roomId/members/:userId

참여자 강퇴 (방장) `[인증필요]`

---

## 6. Chat (PostgreSQL + WebSocket)

> 채팅은 NestJS 서버가 **PostgreSQL** 에 메시지를 영속 저장하고, **Socket.IO (`/chat` namespace)** 로 실시간 브로드캐스트한다.
> 클라이언트는 외부 DB(Firestore 등)에 직접 연결하지 않으며, 모든 채팅 트래픽은 본 서버를 경유한다.
> REST API 와 WebSocket 의 구체 스펙은 아래 **7-1. Chat API** 섹션을 참조한다.

### 역할 분리

| 계층 | 책임 |
|------|------|
| PostgreSQL | `ChatRoom`, `ChatMessage`, `RoomMember` 영속 저장 |
| NestJS REST (`/chat/...`) | 채팅방 목록, 히스토리(커서 페이징), 메시지 전송(저장) |
| NestJS WS (`/chat` namespace) | 저장 직후 같은 방 멤버에게 브로드캐스트 |
| Flutter 클라이언트 | REST 로 송신·히스토리, WS 로 실시간 수신 |

### 서버 자동 처리 트리거

| 시점 | 동작 |
|------|------|
| 방 생성 | `ChatRoom` 1:1 생성 (Room.id 와 동일 식별자) |
| 방 참여 확정 | `RoomMember` 추가 + SYSTEM 메시지 저장·브로드캐스트 |
| 방 퇴장/강퇴 | `RoomMember` 제거 + SYSTEM 메시지 저장·브로드캐스트 |
| 방 삭제/취소 | 채팅 입장은 차단되나 히스토리는 보존 |

---

## 7. Notification API

### POST /notifications/device-token

디바이스 토큰 등록 `[인증필요]`

**Request**

```json
{
  "token": "string",
  "platform": "IOS | ANDROID"
}
```

### GET /notifications

알림 목록 `[인증필요]`

**Query**: `cursor`, `limit(기본20)`

### PATCH /notifications/:notificationId/read

알림 읽음 처리 `[인증필요]`

### PATCH /notifications/read-all

전체 읽음 처리 `[인증필요]`

### GET /notifications/unread-count

안읽은 알림 수 `[인증필요]`

---

## 7-1. Chat API

> 실시간 채팅은 **NestJS WebSocket Gateway (Socket.IO)** 기반.
> - HTTP: 목록/히스토리 조회와 메시지 전송(저장)
> - WS: 실시간 수신 (서버가 저장 직후 브로드캐스트)

### GET /chat/rooms

내가 속한 채팅방 목록 `[인증필요]` — 호스트이거나 `RoomMember` 인 방들 반환.

**Response 200**

```json
[
  {
    "id": "uuid (= Room.id)",
    "roomId": "uuid",
    "roomTitle": "string",
    "lastMessage": "string | null",
    "lastMessageAt": "ISO8601 | null"
  }
]
```

### GET /chat/rooms/:roomId/messages

채팅 메시지 조회 (커서 페이징, 최신순) `[인증필요]`

**Query**: `cursor` (이전 페이지 마지막 `createdAt`), `limit` (기본 50, 최대 100)

**Response 200**

```json
{
  "items": [
    {
      "id": "uuid",
      "roomId": "uuid",
      "senderId": "uuid | null (시스템은 null)",
      "senderNickname": "string",
      "content": "string",
      "type": "TEXT | SYSTEM | IMAGE",
      "createdAt": "ISO8601"
    }
  ],
  "nextCursor": "ISO8601 | null",
  "hasMore": false
}
```

**Error**: `404 NOT_FOUND` (방 없음), `403 FORBIDDEN` (멤버 아님)

### POST /chat/rooms/:roomId/messages

메시지 전송 `[인증필요]`

**Request**

```json
{
  "content": "string (최대 1000자)"
}
```

**Response 201**: 위 item 하나.
저장 성공 시 서버는 즉시 WS `message` 이벤트로 브로드캐스트.

### WebSocket `/chat`

**연결**: `ws(s)://<host>/chat`, 핸드셰이크 `auth: { token: "<accessToken>" }` 또는 `Authorization: Bearer <token>`

**Client → Server 이벤트**

| 이벤트 | Payload | 설명 |
|---|---|---|
| `join` | `{ roomId }` | 해당 방 브로드캐스트 룸에 subscribe |
| `leave` | `{ roomId }` | 구독 해제 |

**Server → Client 이벤트**

| 이벤트 | Payload | 설명 |
|---|---|---|
| `message` | `ChatMessage` | 새 메시지 (자기 발신 메시지도 포함) |

---

## 8. File Upload API

### POST /upload/image

이미지 업로드 `[인증필요]`

**Request**: `multipart/form-data`, field: `image`

**제한**: 최대 5MB, jpg/png/webp

**Response 200**

```json
{
  "url": "https://cdn.example.com/images/uuid.webp"
}
```

---

## 9. Admin API

> 관리자(`User.isAdmin = true`) 전용 엔드포인트. `AdminGuard` + `JwtAuthGuard` 조합.

### POST /admin/login

관리자 로그인

**Request**

```json
{
  "email": "string",
  "password": "string"
}
```

**Response 200**

```json
{
  "accessToken": "string",
  "user": {
    "id": "uuid",
    "email": "string",
    "nickname": "string",
    "isAdmin": true
  }
}
```

**Error**

| 코드 | 상황 |
|------|------|
| 401 UNAUTHORIZED | 관리자 계정 아님 / 비밀번호 불일치 |

### GET /admin/dashboard

대시보드 통계 `[관리자 인증필요]`

**Response 200**

```json
{
  "totalUsers": 0,
  "todayUsers": 0,
  "last7DaysSignups": 0,
  "bannedUsers": 0,
  "currentOnline": 0,
  "todayVisitors": 0,
  "totalRooms": 0,
  "activeRooms": 0,
  "todayRooms": 0,
  "signupTrend": [{ "date": "2026-04-12", "count": 0 }],
  "visitorTrend": [{ "date": "2026-04-12", "count": 0 }],
  "roomTrend":   [{ "date": "2026-04-12", "count": 0 }]
}
```

| 키 | 설명 |
|----|------|
| totalUsers | 전체 가입 유저 수 |
| todayUsers | 오늘 가입한 유저 수 |
| last7DaysSignups | 최근 7일 신규 가입 수 |
| bannedUsers | 정지 상태 유저 수 |
| currentOnline | 현재 온라인(WS 세션 기준) |
| todayVisitors | 오늘 방문자 수 |
| totalRooms | 전체 방 수 |
| activeRooms | 모집중/진행중 방 수 |
| todayRooms | 오늘 생성된 방 수 |
| signupTrend | 최근 30일 가입자 추이 `[{date, count}]` |
| visitorTrend | 최근 30일 방문자 추이 `[{date, count}]` |
| roomTrend | 최근 30일 방 생성 추이 `[{date, count}]` |

### GET /admin/users

유저 목록 `[관리자 인증필요]`

**Query**: `search`, `page(기본 1)`, `limit(기본 20)`

**Response 200**

```json
{
  "items": [ { "id": "uuid", "email": "string", "nickname": "string", "status": "ACTIVE", "createdAt": "ISO8601", "children": [] } ],
  "total": 0,
  "page": 1,
  "limit": 20,
  "totalPages": 0
}
```

### GET /admin/users/:id

유저 상세 `[관리자 인증필요]`

**Response 200**: 위 items 단일 객체 + `roomCount`

### PATCH /admin/users/:id/ban

유저 정지/해제 `[관리자 인증필요]`

**Request**

```json
{
  "banned": true
}
```

**Response 200**

```json
{
  "success": true,
  "status": "BANNED"
}
```

### PATCH /admin/users/:id/verify

유저 본인인증 상태 수동 토글 `[관리자 인증필요]`

> KCP 본인인증/Apple 계정 연동 등과 별개로, 운영자가 직접 본인인증 플래그를 부여하거나 회수할 때 사용한다.

**Request**

```json
{
  "isPhoneVerified": true
}
```

**Response 200**

```json
{
  "success": true,
  "isPhoneVerified": true
}
```

### GET /admin/rooms

방 목록 `[관리자 인증필요]`

**Query**: `search`, `status`, `page(기본 1)`, `limit(기본 20)`

**Response 200**

```json
{
  "items": [ { "id": "uuid", "title": "string", "date": "YYYY-MM-DD", "startTime": "HH:mm", "regionDong": "string", "status": "RECRUITING", "currentMembers": 0, "maxMembers": 0, "host": { "id": "uuid", "nickname": "string", "email": "string" }, "createdAt": "ISO8601" } ],
  "total": 0,
  "page": 1,
  "limit": 20,
  "totalPages": 0
}
```

### GET /admin/rooms/:id

방 상세 `[관리자 인증필요]` — host, members, members.user 포함

### DELETE /admin/rooms/:id

방 강제 삭제(상태 `CANCELLED` 처리) `[관리자 인증필요]`

**Response 200**

```json
{
  "success": true
}
```
