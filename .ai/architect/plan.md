# Architect Plan: 링글 AI 튜터 풀스택 구현 계획

> 작성일: 2026-03-11
> 작성자: Architect Agent
> 상태: **사용자 승인 대기**
> 근거 문서: research.md

---

## 승인 필요 항목 요약

1. DB 스키마 (Membership, UserMembership, Conversation, Message)
2. 프로젝트 폴더 구조
3. API 계약 (엔드포인트 목록, 요청/응답 구조)
4. AI 파이프라인 설계 (SSE Streaming 방식)
5. 유저 식별 방식 (X-User-Id 헤더)
6. Docker Compose 구성

---

## 1. 프로젝트 폴더 구조

```
ringle-backend/                    # Rails 7 API-only
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   └── api/v1/
│   │       ├── memberships_controller.rb
│   │       ├── user_memberships_controller.rb
│   │       ├── payments_controller.rb
│   │       ├── conversations_controller.rb
│   │       └── ai/
│   │           ├── stt_controller.rb
│   │           ├── chat_controller.rb
│   │           └── tts_controller.rb
│   ├── models/
│   │   ├── membership.rb
│   │   ├── user_membership.rb
│   │   ├── conversation.rb
│   │   └── message.rb
│   ├── services/
│   │   ├── openai/
│   │   │   ├── stt_service.rb
│   │   │   ├── chat_service.rb
│   │   │   └── tts_service.rb
│   │   ├── membership_service.rb
│   │   └── payment_service.rb
│   ├── serializers/
│   │   ├── membership_serializer.rb
│   │   └── user_membership_serializer.rb
│   └── concerns/
│       └── membership_authorization.rb
├── spec/
│   ├── models/
│   ├── requests/api/v1/
│   ├── services/
│   └── factories/
├── db/
│   ├── migrate/
│   └── seeds.rb
├── config/
│   ├── routes.rb
│   └── puma.rb
├── Gemfile
└── .env.example

ringle-frontend/                   # Next.js 14 App Router
├── app/
│   ├── page.tsx                   # 홈 (멤버십 현황 + 구매)
│   ├── chat/
│   │   └── page.tsx               # AI 대화 화면
│   ├── admin/
│   │   └── page.tsx               # 어드민 (멤버십 관리)
│   └── layout.tsx
├── components/
│   ├── chat/
│   │   ├── AudioRecorder.tsx      # 마이크 녹음 + 답변완료
│   │   ├── Waveform.tsx           # 오디오 시각화
│   │   ├── ChatMessage.tsx        # 메시지 버블 + 재생 버튼
│   │   └── ConversationPanel.tsx  # 대화 목록
│   └── membership/
│       ├── MembershipCard.tsx
│       └── PurchaseModal.tsx
├── hooks/
│   ├── useAudioRecorder.ts        # MediaRecorder + VAD
│   ├── useConversation.ts         # 대화 상태 + SSE
│   ├── useTTS.ts                  # TTS 오디오 재생
│   └── useMembership.ts           # 멤버십 조회 + 권한
├── lib/
│   ├── api.ts                     # fetch 래퍼
│   └── types.ts                   # 공통 타입
├── tests/
│   ├── components/
│   ├── hooks/
│   ├── e2e/
│   └── mocks/
│       ├── handlers.ts
│       └── server.ts
├── next.config.ts
├── jest.config.js
├── playwright.config.ts
└── package.json

docker-compose.yml
.env.example
README.md
docs/
└── coding_agent_interaction_history.md
```

---

## 2. DB 스키마 (PostgreSQL)

### 2.1 ERD

```
memberships ──< user_memberships >── (user_id: 헤더로 전달)
                     │
                     └──< conversations ──< messages
```

### 2.2 DDL

```sql
-- 멤버십 종류 정의
CREATE TABLE memberships (
  id            SERIAL PRIMARY KEY,
  name          VARCHAR(100) NOT NULL,          -- '베이직', '프리미엄'
  can_learn     BOOLEAN NOT NULL DEFAULT false,  -- 학습 기능
  can_converse  BOOLEAN NOT NULL DEFAULT false,  -- 대화 기능
  can_analyze   BOOLEAN NOT NULL DEFAULT false,  -- 분석 기능
  duration_days INTEGER NOT NULL,               -- 이용기한 (일)
  price_cents   INTEGER NOT NULL DEFAULT 0,     -- 가격 (원)
  description   TEXT,
  created_at    TIMESTAMP(6) NOT NULL,
  updated_at    TIMESTAMP(6) NOT NULL
);

-- 유저 멤버십 인스턴스
CREATE TABLE user_memberships (
  id             SERIAL PRIMARY KEY,
  user_id        INTEGER NOT NULL,              -- 인증 대체: X-User-Id 헤더
  membership_id  INTEGER NOT NULL REFERENCES memberships(id),
  started_at     TIMESTAMP(6) NOT NULL,
  expires_at     TIMESTAMP(6) NOT NULL,         -- started_at + duration_days
  status         VARCHAR(20) NOT NULL DEFAULT 'active', -- active/expired/cancelled
  granted_by     VARCHAR(20) NOT NULL DEFAULT 'purchase', -- purchase/admin
  created_at     TIMESTAMP(6) NOT NULL,
  updated_at     TIMESTAMP(6) NOT NULL
);
CREATE INDEX idx_user_memberships_user_id    ON user_memberships(user_id);
CREATE INDEX idx_user_memberships_expires_at ON user_memberships(expires_at);
CREATE INDEX idx_user_memberships_user_status ON user_memberships(user_id, status);

-- 대화 세션 (optional)
CREATE TABLE conversations (
  id                  SERIAL PRIMARY KEY,
  user_id             INTEGER NOT NULL,
  user_membership_id  INTEGER REFERENCES user_memberships(id),
  topic               VARCHAR(200),
  created_at          TIMESTAMP(6) NOT NULL,
  updated_at          TIMESTAMP(6) NOT NULL
);
CREATE INDEX idx_conversations_user_id ON conversations(user_id);

-- 대화 메시지 (optional)
CREATE TABLE messages (
  id               SERIAL PRIMARY KEY,
  conversation_id  INTEGER NOT NULL REFERENCES conversations(id),
  role             VARCHAR(20) NOT NULL,   -- 'user' / 'assistant'
  content          TEXT NOT NULL,
  created_at       TIMESTAMP(6) NOT NULL,
  updated_at       TIMESTAMP(6) NOT NULL
);
CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
```

### 2.3 시드 데이터

```ruby
# db/seeds.rb
Membership.create!([
  {
    name: '베이직',
    can_learn: true, can_converse: false, can_analyze: false,
    duration_days: 30, price_cents: 129_000,
    description: 'AI 학습 기능 이용 가능'
  },
  {
    name: '프리미엄',
    can_learn: true, can_converse: true, can_analyze: true,
    duration_days: 60, price_cents: 219_000,
    description: 'AI 학습 + 대화 + 분석 모두 이용 가능'
  }
])

# 테스트용 유저 멤버십 (user_id: 1에게 프리미엄 부여)
UserMembership.create!(
  user_id: 1,
  membership: Membership.find_by(name: '프리미엄'),
  started_at: Time.current,
  expires_at: 60.days.from_now,
  granted_by: 'admin'
)
```

---

## 3. API 계약

### 3.1 공통 규칙

- Base URL: `/api/v1`
- 인증: `X-User-Id: {integer}` 헤더 (모든 AI/멤버십 엔드포인트)
- Content-Type: `application/json` (오디오 업로드 제외)
- 성공 응답: `{ "data": {...} }`
- 에러 응답: `{ "error": { "code": "...", "message": "..." } }`

### 3.2 멤버십 관리

```
# 멤버십 종류 목록 (어드민 UI)
GET /api/v1/memberships
Response 200: { "data": [ { "id", "name", "can_learn", "can_converse", "can_analyze", "duration_days", "price_cents" } ] }

# 멤버십 종류 생성 (어드민)
POST /api/v1/memberships
Body: { "name", "can_learn", "can_converse", "can_analyze", "duration_days", "price_cents", "description" }
Response 201: { "data": { Membership } }

# 멤버십 종류 삭제 (어드민)
DELETE /api/v1/memberships/:id
Response 204: (empty)

# 현재 유저의 활성 멤버십 조회
GET /api/v1/user_memberships/current
Header: X-User-Id: 1
Response 200: { "data": { UserMembership + Membership } } or { "data": null }

# 어드민이 유저에게 멤버십 부여
POST /api/v1/user_memberships
Body: { "user_id", "membership_id", "started_at" (optional, default: now) }
Response 201: { "data": { UserMembership } }

# 어드민이 유저 멤버십 삭제
DELETE /api/v1/user_memberships/:id
Response 204: (empty)
```

### 3.3 결제 Mock

```
POST /api/v1/payments
Header: X-User-Id: 1
Body: { "membership_id", "payment_info": { "card_number", "amount" } }
Response 201: { "data": { "payment_id", "status": "success", "user_membership": { UserMembership } } }
Response 422: { "error": { "code": "PAYMENT_FAILED", "message": "결제에 실패했습니다." } }

# PG사 Mock: PaymentService가 내부적으로 MockPgService를 호출
#   - card_number가 "0000-0000-0000-0000"이면 실패 시뮬레이션
#   - 그 외는 성공 처리
```

### 3.4 AI 파이프라인

```
# STT: 오디오 → 텍스트
POST /api/v1/ai/stt
Header: X-User-Id: 1, Content-Type: multipart/form-data
Body: { "audio": <File (webm/mp4/wav)> }
Response 200: { "data": { "text": "안녕하세요..." } }
Response 403: { "error": { "code": "MEMBERSHIP_REQUIRED" } }

# Chat: 텍스트 → AI 응답 (SSE Streaming)
POST /api/v1/ai/chat
Header: X-User-Id: 1, Accept: text/event-stream
Body: { "message": "안녕하세요", "conversation_history": [ {"role", "content"} ] }
Response: text/event-stream
  data: {"chunk": "안녕"}
  data: {"chunk": "하세요"}
  data: {"done": true, "full_text": "안녕하세요!"}

# TTS: 텍스트 → 오디오
POST /api/v1/ai/tts
Header: X-User-Id: 1
Body: { "text": "안녕하세요" }
Response 200: Content-Type: audio/mpeg (binary body)
```

### 3.5 대화 세션 (Optional)

```
POST /api/v1/conversations
Header: X-User-Id: 1
Body: { "topic" (optional) }
Response 201: { "data": { "id", "topic", "created_at" } }

POST /api/v1/conversations/:id/messages
Header: X-User-Id: 1
Body: { "role": "user"|"assistant", "content": "..." }
Response 201: { "data": { Message } }

GET /api/v1/conversations/:id/messages
Header: X-User-Id: 1
Response 200: { "data": [ Message ] }
```

---

## 4. AI 파이프라인 설계

### 4.1 SSE Streaming 구현 (Rails)

```ruby
# Option A: ActionController::Live (선택)
# 장점: Rails 표준, 추가 라이브러리 불필요
# 단점: Puma 스레드 관리 필요

# Option B: Rack Hijack
# 단점: 저수준 API, 복잡도 높음

# → Option A 선택
class Api::V1::Ai::ChatController < ApplicationController
  include ActionController::Live

  def create
    response.headers['Content-Type']  = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no'

    full_text = ''
    OpenaiChatService.new.stream(params[:message], params[:conversation_history]) do |chunk|
      full_text += chunk
      response.stream.write("data: #{{ chunk: chunk }.to_json}\n\n")
    end
    response.stream.write("data: #{{ done: true, full_text: full_text }.to_json}\n\n")
  rescue => e
    response.stream.write("data: #{{ error: e.message }.to_json}\n\n")
  ensure
    response.stream.close
  end
end
```

### 4.2 SSE 소비 (Next.js)

```typescript
// Option A: fetch + ReadableStream (선택)
// 장점: POST 요청 가능 (body 포함), EventSource는 GET만 지원
// 단점: 브라우저 구현 약간 복잡

// Option B: EventSource
// 단점: GET 전용, body 전송 불가

// → Option A 선택
async function streamChat(message: string, history: Message[]) {
  const response = await fetch('/api/v1/ai/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-User-Id': getUserId() },
    body: JSON.stringify({ message, conversation_history: history }),
  })
  const reader = response.body!.getReader()
  const decoder = new TextDecoder()

  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    const lines = decoder.decode(value).split('\n')
    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const data = JSON.parse(line.slice(6))
        if (data.chunk) onChunk(data.chunk)
        if (data.done) onComplete(data.full_text)
      }
    }
  }
}
```

### 4.3 Rate Limiting (rack-attack)

```ruby
# config/initializers/rack_attack.rb
# AI 엔드포인트: 유저당 분당 10회
Rack::Attack.throttle('ai/per_user', limit: 10, period: 1.minute) do |req|
  req.get_header('HTTP_X_USER_ID') if req.path.start_with?('/api/v1/ai/')
end
```

---

## 5. 트레이드오프

| 결정 | 선택 | 대안 | 이유 |
|------|------|------|------|
| 유저 식별 | X-User-Id 헤더 | 쿼리 파라미터 | REST 관례, 실제 인증으로 교체 용이 |
| Chat Streaming | ActionController::Live | Sidekiq/WebSocket | 추가 인프라 불필요, 과제 범위에 적합 |
| SSE 소비 | fetch + ReadableStream | EventSource | POST body 전송 필요 |
| TTS 전달 | binary 직접 응답 | S3 URL 반환 | 파일 스토리지 불필요, 간결 |
| 대화 기록 | 클라이언트 상태 (기본) + DB API (optional) | DB 전용 | 필수는 클라이언트로, optional은 DB |
| 만료 처리 | 요청 시점 expires_at 비교 | Background Job | 과제 범위, 단순함 |

---

## 6. 구현 순서 및 담당자 지정

### Phase 1: 프로젝트 뼈대 (Architect → 전체)
```
[ ] Docker Compose (PostgreSQL + Rails + Next.js)
[ ] Rails 프로젝트 생성 (--api --database=postgresql)
[ ] Next.js 프로젝트 생성 (--typescript --app --tailwind)
[ ] .env.example 작성
```

### Phase 2: Backend 멤버십 도메인 (Backend Engineer)
```
[ ] DB Migration: memberships, user_memberships
[ ] Model: Membership, UserMembership (유효성 검사, 스코프)
[ ] FactoryBot 팩토리
[ ] Seeds: 베이직/프리미엄 멤버십 + 테스트 유저 멤버십
[ ] MembershipAuthorization concern
[ ] MembershipsController (CRUD)
[ ] UserMembershipsController (조회/할당/삭제)
[ ] RSpec: 모델 + 요청 테스트
```

### Phase 3: Backend AI 파이프라인 (Backend Engineer)
```
[ ] OpenAI::SttService (Whisper)
[ ] OpenAI::ChatService (GPT-4o Streaming)
[ ] OpenAI::TtsService (TTS)
[ ] Ai::SttController
[ ] Ai::ChatController (ActionController::Live)
[ ] Ai::TtsController
[ ] PaymentService (Mock PG)
[ ] PaymentsController
[ ] rack-attack Rate Limiting
[ ] RSpec: 서비스 (stub) + 컨트롤러 테스트
```

### Phase 4: Backend 대화 세션 (Backend Engineer - optional)
```
[ ] DB Migration: conversations, messages
[ ] Model: Conversation, Message
[ ] ConversationsController (세션 생성 + 메시지 CRUD)
[ ] RSpec
```

### Phase 5: Frontend 멤버십 UI (Frontend Engineer)
```
[ ] lib/types.ts (Membership, UserMembership 타입)
[ ] lib/api.ts (fetch 래퍼 + X-User-Id 헤더 자동 주입)
[ ] useMembership hook
[ ] MembershipCard 컴포넌트
[ ] PurchaseModal 컴포넌트
[ ] 홈 페이지 (app/page.tsx)
[ ] 어드민 페이지 (app/admin/page.tsx)
[ ] Jest + MSW 테스트
```

### Phase 6: Frontend AI 대화 (Frontend Engineer - 핵심)
```
[ ] useAudioRecorder hook (MediaRecorder + VAD)
[ ] Waveform 컴포넌트 (AudioContext 시각화)
[ ] useConversation hook (SSE 스트리밍 소비)
[ ] useTTS hook (오디오 재생 + 재청취)
[ ] ChatMessage 컴포넌트 (재생 버튼 포함)
[ ] ConversationPanel 컴포넌트
[ ] 대화 화면 (app/chat/page.tsx)
[ ] Jest + MSW 테스트
```

### Phase 7: E2E + 문서화 (QA Engineer + Architect)
```
[ ] Playwright E2E: 멤버십 구매 플로우
[ ] Playwright E2E: AI 대화 전체 플로우 (마이크 mock)
[ ] README.md (실행 방법, 설계 배경, 테스트 방법)
[ ] docs/coding_agent_interaction_history.md
```

---

## 7. 환경변수 목록 (.env.example)

```bash
# Backend (.env)
DATABASE_URL=postgresql://postgres:password@localhost:5432/ringle_development
OPENAI_API_KEY=sk-...
RAILS_ENV=development

# Frontend (.env.local)
NEXT_PUBLIC_API_URL=http://localhost:3001
NEXT_PUBLIC_USER_ID=1   # 개발/데모용 임시 user_id
```

---

## 8. 다음 단계

승인 후 구현 순서:
1. **Architect**: Phase 1 (Docker Compose + 프로젝트 뼈대) 직접 구성
2. **Backend Engineer**: Phase 2 → research.md → plan.md 작성 후 구현
3. **Frontend Engineer**: Phase 5 → research.md → plan.md 작성 후 구현
4. **Backend Engineer**: Phase 3 → Phase 4
5. **Frontend Engineer**: Phase 6
6. **QA Engineer**: Phase 7

---

**사용자 승인을 기다립니다. "YES"를 입력하면 Phase 1부터 구현을 시작합니다.**
