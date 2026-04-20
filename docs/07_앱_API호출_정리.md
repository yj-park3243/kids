# 앱 API 호출 정리

> Flutter 앱(`app/lib/`)에서 실제로 호출하는 모든 서버 API와 Firestore 직접 연동을 정리한 문서입니다.
> 분석 기준일: 2026-04-06

---

## Base URL 구성

```
개발: http://localhost:3000/v1
운영: http://43.201.221.240:3000/v1
```

- `ApiConstants.apiUrl` = `{baseUrl}/v1`
- 모든 엔드포인트는 `/v1` 프리픽스 포함
- 타임아웃: 연결 10초, 수신 15초

---

## 1. 인증 (Auth)

### 1-1. POST /v1/auth/social
- **호출 파일**: `features/auth/data/auth_repository.dart` > `socialLogin()`
- **호출 화면**: 로그인 화면 (`login_screen.dart`) - 카카오/Apple/Google 버튼 (현재 TODO 상태, `_showComingSoon`으로 대체)
- **Request Body**:
  ```json
  {
    "provider": "KAKAO|APPLE|GOOGLE",
    "accessToken": "소셜 액세스 토큰",
    "idToken": "ID 토큰 (선택)"
  }
  ```
- **Response**:
  ```json
  {
    "data": {
      "accessToken": "JWT",
      "refreshToken": "리프레시 토큰",
      "isNewUser": true,
      "user": { User 객체 }
    }
  }
  ```
- **인증 필요**: 아니오
- **서버 구현**: `auth.controller.ts` > `socialLogin()`
- **비고**: 앱 UI에 버튼은 있으나 실제 소셜 로그인 SDK 연동은 TODO 상태

### 1-2. POST /v1/auth/email/login
- **호출 파일**: `features/auth/data/auth_repository.dart` > `emailLogin()`
- **호출 화면**: 이메일 로그인 화면 (`email_login_screen.dart`) > `_login()`
- **Request Body**:
  ```json
  {
    "email": "user@example.com",
    "password": "비밀번호"
  }
  ```
- **Response**: socialLogin과 동일 형태
- **인증 필요**: 아니오
- **서버 구현**: `auth.controller.ts` > `emailLogin()`

### 1-3. POST /v1/auth/email/register
- **호출 파일**: `features/auth/data/auth_repository.dart` > `emailRegister()`
- **호출 화면**: 이메일 회원가입 화면 (`email_register_screen.dart`) > `_register()`
- **Request Body**:
  ```json
  {
    "email": "user@example.com",
    "password": "비밀번호"
  }
  ```
- **Response**: socialLogin과 동일 형태 (isNewUser: true)
- **인증 필요**: 아니오
- **서버 구현**: `auth.controller.ts` > `emailRegister()`

### 1-4. POST /v1/auth/refresh
- **호출 파일**: `core/network/api_interceptor.dart` > `onError()` (401 에러 시 자동 호출)
- **호출 화면**: 자동 (인터셉터에서 401 응답 시)
- **Request Body**:
  ```json
  {
    "refreshToken": "리프레시 토큰"
  }
  ```
- **Response**:
  ```json
  {
    "data": {
      "accessToken": "새 JWT",
      "refreshToken": "새 리프레시 토큰"
    }
  }
  ```
- **인증 필요**: 아니오
- **서버 구현**: `auth.controller.ts` > `refresh()`

### 1-5. POST /v1/auth/logout
- **호출 파일**: `features/auth/data/auth_repository.dart` > `logout()`
- **호출 화면**: 마이페이지 (`mypage_screen.dart`) > `_logout()`
- **Request Body**: 없음
- **Response**: 200 OK
- **인증 필요**: 예
- **서버 구현**: `auth.controller.ts` > `logout()`

### 1-6. POST /v1/auth/email/reset-password
- **호출 파일**: `features/auth/data/auth_repository.dart` > `resetPassword()`
- **호출 화면**: 이메일 로그인 화면의 "비밀번호를 잊으셨나요?" 버튼 (현재 TODO 상태)
- **Request Body**:
  ```json
  {
    "email": "user@example.com"
  }
  ```
- **Response**: 200 OK — `{ "success": true, "message": "..." }` (계정 존재 여부와 무관하게 동일 응답)
- **인증 필요**: 아니오
- **서버 구현**: `auth.controller.ts` > `resetPassword()` (이메일 실발송은 외부 서비스 연동 대기)
- **비고**: 앱 UI(이메일 로그인 화면의 "비밀번호를 잊으셨나요?" 버튼)와 연결 필요.

---

## 2. 유저 (User)

### 2-1. POST /v1/users/profile
- **호출 파일**: `features/auth/data/auth_repository.dart` > `setupProfile()`
- **호출 화면**: 프로필 설정 화면 (`profile_setup_screen.dart`) > `_submit()`
- **Request Body**:
  ```json
  {
    "nickname": "닉네임",
    "regionSido": "서울특별시",
    "regionSigungu": "강남구",
    "regionDong": "역삼동",
    "profileImageUrl": "이미지 URL (선택)",
    "introduction": "자기소개 (선택)"
  }
  ```
- **Response**:
  ```json
  {
    "data": { User 객체 }
  }
  ```
- **인증 필요**: 예
- **서버 구현**: `user.controller.ts` > `createProfile()`

### 2-2. GET /v1/users/me
- **호출 파일**: `features/auth/data/auth_repository.dart` > `getMyProfile()`
- **호출 화면**:
  - 스플래시 화면 (`splash_screen.dart`) > `_navigate()` (앱 시작 시 인증 확인)
  - AuthProvider > `checkAuth()`, `completeChildSetup()` (아이 등록 완료 후 프로필 재조회)
- **Request Body**: 없음
- **Query Params**: 없음
- **Response**:
  ```json
  {
    "data": {
      "id": "uuid",
      "nickname": "닉네임",
      "email": "이메일",
      "profileImageUrl": "URL",
      "introduction": "자기소개",
      "regionSido": "시도",
      "regionSigungu": "시군구",
      "regionDong": "동",
      "isProfileComplete": true,
      "isPhoneVerified": false,
      "authProvider": "EMAIL",
      "children": [{ Child 객체 }],
      "createdAt": "ISO 날짜"
    }
  }
  ```
- **인증 필요**: 예
- **서버 구현**: `user.controller.ts` > `getMe()`

### 2-3. DELETE /v1/users/me
- **호출 파일**: `features/auth/data/auth_repository.dart` > `deleteAccount()`
- **호출 화면**: 마이페이지 (`mypage_screen.dart`) > `_deleteAccount()`
- **Request Body**:
  ```json
  {
    "reason": "탈퇴 사유 (선택, null 가능)"
  }
  ```
- **Response**: 200 OK
- **인증 필요**: 예
- **서버 구현**: `user.controller.ts` > `deleteMe()`

### 2-4. GET /v1/users/check-nickname
- **호출 파일**: `features/auth/data/auth_repository.dart` > `checkNickname()`
- **호출 화면**: 프로필 설정 화면 (`profile_setup_screen.dart`) > `_checkNickname()` (중복확인 버튼)
- **Query Params**: `?nickname=닉네임`
- **Response**:
  ```json
  {
    "data": {
      "available": true
    }
  }
  ```
- **인증 필요**: 예
- **서버 구현**: `user.controller.ts` > `checkNickname()`

### 2-5. PATCH /v1/users/me (미호출)
- **호출 파일**: 앱에서 호출하지 않음
- **호출 화면**: 프로필 수정 화면 (`profile_edit_screen.dart`) > `_save()` 에 `// TODO: Call update profile API` 주석만 있음
- **서버 구현**: `user.controller.ts` > `updateMe()` (서버에는 구현됨)
- **비고**: 서버에 PATCH /users/me 가 구현되어 있으나, 앱에서 아직 호출하지 않음

---

## 3. 아이 (Child)

### 3-1. POST /v1/children
- **호출 파일**: `features/auth/data/auth_repository.dart` > `addChild()`
- **호출 화면**: 아이 정보 등록 화면 (`child_setup_screen.dart`) > `_submit()` (최대 5명 반복 호출)
- **Request Body**:
  ```json
  {
    "nickname": "아이 태명/별명",
    "birthYear": 2024,
    "birthMonth": 3,
    "gender": "MALE|FEMALE|null"
  }
  ```
- **Response**:
  ```json
  {
    "data": {
      "id": "uuid",
      "nickname": "별명",
      "birthYear": 2024,
      "birthMonth": 3,
      "ageMonths": 24,
      "gender": "MALE",
      "createdAt": "ISO 날짜"
    }
  }
  ```
- **인증 필요**: 예
- **서버 구현**: `child.controller.ts` > `create()`

---

## 4. 방 (Room)

### 4-1. GET /v1/rooms
- **호출 파일**: `features/home/data/home_repository.dart` > `getRooms()`
- **호출 화면**: 홈 화면 (`home_screen.dart`) > `loadRooms()`, `loadMore()` (필터링 + 무한스크롤)
- **Query Params**:
  ```
  ?regionDong=역삼동       (선택)
  &dateFrom=2026-04-06    (선택)
  &dateTo=2026-04-13      (선택)
  &ageMonth=24            (선택)
  &placeType=PLAYGROUND   (선택)
  &cursor=커서값           (선택, 페이지네이션)
  &limit=20               (기본 20)
  ```
- **Response**:
  ```json
  {
    "data": {
      "items": [{ Room 객체 }],
      "nextCursor": "다음 페이지 커서",
      "hasMore": true
    }
  }
  ```
- **인증 필요**: 예
- **서버 구현**: `room.controller.ts` > `findAll()`

### 4-2. GET /v1/rooms/:roomId
- **호출 파일**:
  - `features/home/data/home_repository.dart` > `getRoomDetail()`
  - `features/room/data/room_repository.dart` > `getRoomDetail()`
- **호출 화면**: 방 상세 화면 (`room_detail_screen.dart`) > `loadRoom()`
- **Path Params**: `roomId` (UUID)
- **Response**:
  ```json
  {
    "data": {
      "id": "uuid",
      "title": "제목",
      "description": "설명",
      "date": "2026-04-10",
      "startTime": "14:00",
      "endTime": "16:00",
      "regionSido": "서울특별시",
      "regionSigungu": "강남구",
      "regionDong": "역삼동",
      "ageMonthMin": 12,
      "ageMonthMax": 36,
      "placeType": "PLAYGROUND",
      "placeName": "장소명",
      "placeAddress": "주소",
      "latitude": 37.5,
      "longitude": 127.0,
      "maxMembers": 5,
      "currentMembers": 3,
      "joinType": "FREE|APPROVAL",
      "cost": 0,
      "costDescription": "비용 설명",
      "tags": ["태그1", "태그2"],
      "status": "RECRUITING",
      "host": { RoomHost 객체 },
      "members": [{ RoomMember 객체 }],
      "myStatus": "ACCEPTED|PENDING|null",
      "canJoin": true,
      "canJoinReason": "사유",
      "chatRoomId": "Firestore chatRoom ID",
      "createdAt": "ISO 날짜"
    }
  }
  ```
- **인증 필요**: 예
- **서버 구현**: `room.controller.ts` > `getDetail()`

### 4-3. POST /v1/rooms
- **호출 파일**: `features/room/data/room_repository.dart` > `createRoom()`
- **호출 화면**: 방 생성 화면 (`room_create_screen.dart`) > `_submit()`
- **Request Body**:
  ```json
  {
    "title": "모임 제목",
    "description": "모임 설명",
    "regionSido": "서울특별시",
    "regionSigungu": "강남구",
    "regionDong": "역삼동",
    "date": "2026-04-10",
    "startTime": "14:00",
    "endTime": "16:00",
    "ageMonthMin": 12,
    "ageMonthMax": 36,
    "placeType": "PLAYGROUND",
    "placeName": "장소명 (선택)",
    "placeAddress": "주소 (선택)",
    "maxMembers": 5,
    "joinType": "FREE|APPROVAL",
    "cost": 0,
    "costDescription": "비용 설명 (선택)",
    "tags": ["태그1", "태그2"]
  }
  ```
- **Response**:
  ```json
  {
    "data": { Room 객체 }
  }
  ```
- **인증 필요**: 예
- **서버 구현**: `room.controller.ts` > `create()`

### 4-4. POST /v1/rooms/:roomId/join
- **호출 파일**: `features/room/data/room_repository.dart` > `joinRoom()`
- **호출 화면**: 방 상세 화면 (`room_detail_screen.dart`) > `_joinRoom()` (참여하기/참여 신청 버튼)
- **Path Params**: `roomId`
- **Request Body**: 없음
- **Response**:
  ```json
  {
    "data": {
      "status": "ACCEPTED|PENDING"
    }
  }
  ```
- **인증 필요**: 예
- **서버 구현**: `room.controller.ts` > `join()`

### 4-5. DELETE /v1/rooms/:roomId/join
- **호출 파일**: `features/room/data/room_repository.dart` > `leaveRoom()`
- **호출 화면**: RoomDetailProvider > `leaveRoom()` (방 나가기 기능, 현재 UI에서 직접 호출하는 버튼 미확인)
- **Path Params**: `roomId`
- **Request Body**: 없음
- **Response**: 200 OK
- **인증 필요**: 예
- **서버 구현**: `room.controller.ts` > `cancelJoin()`

### 4-6. GET /v1/rooms/:roomId/join-requests
- **호출 파일**: `features/room/data/room_repository.dart` > `getJoinRequests()`
- **호출 화면**: 참여 관리 화면 (`join_request_screen.dart`) > `_loadRequests()`
- **Path Params**: `roomId`
- **Response**:
  ```json
  {
    "data": {
      "items": [
        {
          "id": "uuid",
          "user": { RoomMember 객체 },
          "status": "PENDING",
          "createdAt": "ISO 날짜"
        }
      ]
    }
  }
  ```
- **인증 필요**: 예
- **서버 구현**: `room.controller.ts` > `getJoinRequests()`

### 4-7. PATCH /v1/rooms/:roomId/join-requests/:requestId
- **호출 파일**: `features/room/data/room_repository.dart` > `handleJoinRequest()`
- **호출 화면**: 참여 관리 화면 (`join_request_screen.dart`) > `_handleRequest()` (수락/거절 버튼)
- **Path Params**: `roomId`, `requestId`
- **Request Body**:
  ```json
  {
    "action": "ACCEPT|REJECT"
  }
  ```
- **Response**: 200 OK
- **인증 필요**: 예
- **서버 구현**: `room.controller.ts` > `handleJoinRequest()`

### 4-8. DELETE /v1/rooms/:roomId
- **호출 파일**: `features/room/data/room_repository.dart` > `cancelRoom()`
- **호출 화면**: 방 상세 화면 (`room_detail_screen.dart`) > `_cancelRoom()` (방장 전용, 팝업 메뉴 > 모임 취소)
- **Path Params**: `roomId`
- **Request Body**: 없음
- **Response**: 200 OK
- **인증 필요**: 예
- **서버 구현**: `room.controller.ts` > `cancel()`

### 4-9. GET /v1/rooms/my
- **호출 파일**: `features/room/data/room_repository.dart` > `getMyRooms()`
- **호출 화면**: 내 모임 화면 (`my_rooms_screen.dart`) > `_loadRooms()` (예정된 모임/지난 모임 탭)
- **Query Params**:
  ```
  ?type=ALL               (기본값)
  &status=UPCOMING|PAST   (탭에 따라 변경)
  ```
- **Response**:
  ```json
  {
    "data": {
      "items": [{ Room 객체 }]
    }
  }
  ```
- **인증 필요**: 예
- **서버 구현**: `room.controller.ts` > `getMyRooms()`

### 4-10. GET /v1/rooms/map
- **호출 파일**: `features/room/data/room_repository.dart` > `getMapRooms()`
- **호출 화면**: 지도 화면 (`map_screen.dart`) > `_loadMapData()`
- **Query Params**:
  ```
  ?swLat=37.4
  &swLng=126.8
  &neLat=37.7
  &neLng=127.2
  &ageMonth=24     (선택)
  &zoomLevel=12    (선택)
  ```
- **Response**:
  ```json
  {
    "data": {
      "mode": "CLUSTER|PIN",
      "clusters": [
        {
          "regionDong": "역삼동",
          "count": 5,
          "latitude": 37.5,
          "longitude": 127.0
        }
      ],
      "pins": [
        {
          "id": "roomId",
          "title": "모임 제목",
          "date": "2026-04-10",
          "startTime": "14:00",
          "ageMonthMin": 12,
          "ageMonthMax": 36,
          "currentMembers": 3,
          "maxMembers": 5,
          "latitude": 37.5,
          "longitude": 127.0
        }
      ]
    }
  }
  ```
- **인증 필요**: 예
- **서버 구현**: `room.controller.ts` > `getMapRooms()`

---

## 5. 채팅 (Chat) - Firestore 직접 연동

채팅은 서버 REST API가 아닌 **Cloud Firestore에 직접 연결**하여 실시간 동기화합니다.

### 5-1. Firestore: 채팅방 목록 조회 (Stream)
- **호출 파일**: `features/chat/data/chat_repository.dart` > `getChatRooms()`
- **호출 화면**: 채팅 목록 화면 (`chat_list_screen.dart`) > `StreamBuilder`
- **Firestore 경로**: `chatRooms` (컬렉션)
- **쿼리**:
  ```
  .where('memberIds', arrayContains: userId)
  .orderBy('lastMessageAt', descending: true)
  ```
- **반환 타입**: `Stream<List<ChatRoom>>`

### 5-2. Firestore: 메시지 목록 조회 (Stream)
- **호출 파일**: `features/chat/data/chat_repository.dart` > `getMessages()`
- **호출 화면**: 채팅방 화면 (`chat_room_screen.dart`) > `StreamBuilder`
- **Firestore 경로**: `chatRooms/{chatRoomId}/messages` (서브컬렉션)
- **쿼리**:
  ```
  .orderBy('createdAt', descending: true)
  .limit(50)
  ```
- **반환 타입**: `Stream<List<ChatMessage>>`

### 5-3. Firestore: 이전 메시지 로드 (페이지네이션)
- **호출 파일**: `features/chat/data/chat_repository.dart` > `getOlderMessages()`
- **호출 화면**: 현재 UI에서 직접 호출하지 않음 (스크롤 페이지네이션용으로 준비)
- **Firestore 경로**: `chatRooms/{chatRoomId}/messages`
- **쿼리**:
  ```
  .orderBy('createdAt', descending: true)
  .startAfterDocument(lastDoc)
  .limit(50)
  ```
- **반환 타입**: `Future<List<ChatMessage>>`

### 5-4. Firestore: 메시지 전송
- **호출 파일**: `features/chat/data/chat_repository.dart` > `sendMessage()`
- **호출 화면**: 채팅방 화면 (`chat_room_screen.dart`) > `_sendMessage()` (전송 버튼 / Enter 키)
- **Firestore 작업** (batch write):
  1. `chatRooms/{chatRoomId}/messages/{auto-id}` 에 메시지 문서 추가
  2. `chatRooms/{chatRoomId}` 에 lastMessage, lastMessageAt 업데이트
- **메시지 데이터**:
  ```json
  {
    "senderId": "유저 ID",
    "senderNickname": "닉네임",
    "content": "메시지 내용",
    "type": "TEXT",
    "createdAt": "서버 타임스탬프"
  }
  ```

---

## 6. 알림 (Notification)

### 6-1. GET /v1/notifications
- **호출 파일**: `features/notification/data/notification_repository.dart` > `getNotifications()`
- **호출 화면**: 알림 화면 (`notification_screen.dart`) > `_loadNotifications()`
- **Query Params**: `?cursor=커서값 (선택)`
- **Response**:
  ```json
  {
    "data": {
      "items": [
        {
          "id": "uuid",
          "type": "JOIN_REQUEST|JOIN_ACCEPTED|JOIN_REJECTED|ROOM_CANCELLED|ROOM_REMINDER|NEW_CHAT|NEW_ROOM",
          "title": "알림 제목",
          "body": "알림 본문",
          "data": { "roomId": "uuid", "chatRoomId": "id" },
          "isRead": false,
          "createdAt": "ISO 날짜"
        }
      ]
    }
  }
  ```
- **인증 필요**: 예
- **서버 구현**: `notification.controller.ts` > `findAll()`

### 6-2. PATCH /v1/notifications/:id/read
- **호출 파일**: `features/notification/data/notification_repository.dart` > `markAsRead()`
- **호출 화면**: 알림 화면 (`notification_screen.dart`) > 알림 항목 탭 시 (`onTap`)
- **Path Params**: `id` (알림 ID)
- **Request Body**: 없음
- **Response**: 200 OK
- **인증 필요**: 예
- **서버 구현**: `notification.controller.ts` > `markAsRead()`

### 6-3. PATCH /v1/notifications/read-all
- **호출 파일**: `features/notification/data/notification_repository.dart` > `markAllAsRead()`
- **호출 화면**: 알림 화면 (`notification_screen.dart`) > "모두 읽음" 버튼 (`_markAllAsRead()`)
- **Request Body**: 없음
- **Response**: 200 OK
- **인증 필요**: 예
- **서버 구현**: `notification.controller.ts` > `markAllAsRead()`

### 6-4. GET /v1/notifications/unread-count
- **호출 파일**:
  - `features/home/data/home_repository.dart` > `getUnreadNotificationCount()`
  - `features/notification/data/notification_repository.dart` > `getUnreadCount()`
- **호출 화면**: 홈 화면 (`home_screen.dart`) > `loadUnreadCount()` (상단 알림 배지)
- **Query Params**: 없음
- **Response**:
  ```json
  {
    "data": {
      "count": 5
    }
  }
  ```
- **인증 필요**: 예
- **서버 구현**: `notification.controller.ts` > `getUnreadCount()`

---

## 7. 파일 업로드 (Upload)

### 7-1. POST /v1/upload/image
- **호출 파일**: `features/auth/data/auth_repository.dart` > `uploadImage()`
- **호출 화면**: 프로필 설정 화면 (`profile_setup_screen.dart`) > `_submit()` (프로필 사진 선택 후)
- **Request**: `multipart/form-data`
  ```
  image: (파일 바이너리)
  ```
- **Response**:
  ```json
  {
    "data": {
      "url": "https://storage.example.com/images/uuid.jpg"
    }
  }
  ```
- **인증 필요**: 예
- **서버 구현**: `upload.controller.ts` > `uploadImage()`
- **비고**: maxWidth 512, imageQuality 80으로 압축 후 업로드

---

## 8. 인터셉터에서 자동 호출되는 API

### 8-1. POST /v1/auth/refresh (자동 토큰 갱신)
- **호출 파일**: `core/network/api_interceptor.dart` > `AuthInterceptor.onError()`
- **동작**: 401 응답을 받으면 자동으로 refresh 토큰을 사용해 새 access token을 발급받고, 실패한 요청을 재시도
- **실패 시**: 저장된 토큰 삭제 (SecureStorage.clearTokens())

---

## 서버에 구현되어 있으나 앱에서 호출하지 않는 API

| Method | Endpoint | 서버 파일 | 비고 |
|--------|----------|-----------|------|
| PATCH | /v1/users/me | user.controller.ts | 프로필 수정 - 앱에 TODO로 남아있음 |
| GET | /v1/users/:userId | user.controller.ts | 다른 유저 프로필 조회 |
| GET | /v1/children | child.controller.ts | 내 아이 목록 조회 (별도 호출 없이 /users/me 에 포함) |
| PATCH | /v1/children/:childId | child.controller.ts | 아이 정보 수정 |
| DELETE | /v1/children/:childId | child.controller.ts | 아이 정보 삭제 |
| PATCH | /v1/rooms/:roomId | room.controller.ts | 방 수정 (방장) |
| DELETE | /v1/rooms/:roomId/members/:userId | room.controller.ts | 참여자 강퇴 (방장) |
| POST | /v1/notifications/device-token | notification.controller.ts | FCM 디바이스 토큰 등록 |

---

## 앱에 정의되어 있으나 서버에 없는 API

| Method | Endpoint | 앱 파일 | 비고 |
|--------|----------|---------|------|
| POST | /v1/auth/email/reset-password | auth_repository.dart | 비밀번호 재설정 - 서버 구현 완료, 앱 UI 연결 필요 |

---

## 요약 테이블

| # | Method | Endpoint | 호출 파일 | 화면 | 인증 | 상태 |
|---|--------|----------|-----------|------|------|------|
| 1 | POST | /v1/auth/social | auth_repository.dart | login_screen.dart | 아니오 | ✅ 서버 구현됨 (앱 소셜SDK TODO) |
| 2 | POST | /v1/auth/email/login | auth_repository.dart | email_login_screen.dart | 아니오 | ✅ 서버 구현됨 |
| 3 | POST | /v1/auth/email/register | auth_repository.dart | email_register_screen.dart | 아니오 | ✅ 서버 구현됨 |
| 4 | POST | /v1/auth/refresh | api_interceptor.dart | (자동 - 인터셉터) | 아니오 | ✅ 서버 구현됨 |
| 5 | POST | /v1/auth/logout | auth_repository.dart | mypage_screen.dart | 예 | ✅ 서버 구현됨 |
| 6 | POST | /v1/auth/email/reset-password | auth_repository.dart | (미호출 - UI TODO) | 아니오 | ✅ 서버 구현 (이메일 발송 미연동) |
| 7 | POST | /v1/users/profile | auth_repository.dart | profile_setup_screen.dart | 예 | ✅ 서버 구현됨 |
| 8 | GET | /v1/users/me | auth_repository.dart | splash_screen.dart 외 | 예 | ✅ 서버 구현됨 |
| 9 | DELETE | /v1/users/me | auth_repository.dart | mypage_screen.dart | 예 | ✅ 서버 구현됨 |
| 10 | GET | /v1/users/check-nickname | auth_repository.dart | profile_setup_screen.dart | 예 | ✅ 서버 구현됨 |
| 11 | POST | /v1/children | auth_repository.dart | child_setup_screen.dart | 예 | ✅ 서버 구현됨 |
| 12 | GET | /v1/rooms | home_repository.dart | home_screen.dart | 예 | ✅ 서버 구현됨 |
| 13 | GET | /v1/rooms/:roomId | room_repository.dart | room_detail_screen.dart | 예 | ✅ 서버 구현됨 |
| 14 | POST | /v1/rooms | room_repository.dart | room_create_screen.dart | 예 | ✅ 서버 구현됨 |
| 15 | POST | /v1/rooms/:roomId/join | room_repository.dart | room_detail_screen.dart | 예 | ✅ 서버 구현됨 |
| 16 | DELETE | /v1/rooms/:roomId/join | room_repository.dart | (leaveRoom 메서드) | 예 | ✅ 서버 구현됨 |
| 17 | GET | /v1/rooms/:roomId/join-requests | room_repository.dart | join_request_screen.dart | 예 | ✅ 서버 구현됨 |
| 18 | PATCH | /v1/rooms/:roomId/join-requests/:requestId | room_repository.dart | join_request_screen.dart | 예 | ✅ 서버 구현됨 |
| 19 | DELETE | /v1/rooms/:roomId | room_repository.dart | room_detail_screen.dart | 예 | ✅ 서버 구현됨 |
| 20 | GET | /v1/rooms/my | room_repository.dart | my_rooms_screen.dart | 예 | ✅ 서버 구현됨 |
| 21 | GET | /v1/rooms/map | room_repository.dart | map_screen.dart | 예 | ✅ 서버 구현됨 |
| 22 | GET | /v1/notifications | notification_repository.dart | notification_screen.dart | 예 | ✅ 서버 구현됨 |
| 23 | PATCH | /v1/notifications/:id/read | notification_repository.dart | notification_screen.dart | 예 | ✅ 서버 구현됨 |
| 24 | PATCH | /v1/notifications/read-all | notification_repository.dart | notification_screen.dart | 예 | ✅ 서버 구현됨 |
| 25 | GET | /v1/notifications/unread-count | home_repository.dart, notification_repository.dart | home_screen.dart | 예 | ✅ 서버 구현됨 |
| 26 | POST | /v1/upload/image | auth_repository.dart | profile_setup_screen.dart | 예 | ✅ 서버 구현됨 |
| - | Firestore | chatRooms (채팅방 목록) | chat_repository.dart | chat_list_screen.dart | - | ✅ Firestore |
| - | Firestore | chatRooms/{id}/messages (메시지) | chat_repository.dart | chat_room_screen.dart | - | ✅ Firestore |
| - | Firestore | 메시지 전송 + 채팅방 업데이트 | chat_repository.dart | chat_room_screen.dart | - | ✅ Firestore |

---

## 통계 요약

- **REST API 총 호출**: 26개 엔드포인트 (앱에서 호출하는 것)
- **Firestore 직접 연동**: 4개 작업 (채팅방 목록, 메시지 목록, 이전 메시지, 메시지 전송)
- **서버 구현 완료**: 25개 / 26개 (96%)
- **서버 미구현**: 0개 (모두 구현됨, 외부 서비스 연동만 남음)
- **서버에만 구현 (앱 미호출)**: 8개 엔드포인트
- **앱 TODO 상태**: 소셜 로그인 SDK 연동, 비밀번호 재설정, 프로필 수정 API 호출
