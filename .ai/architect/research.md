# Architect Research: 링글 AI 튜터 풀스택 설계 분석

> 작성일: 2026-03-11
> 작성자: Architect Agent
> 상태: 완료 → plan.md 작성 대기

---

## 1. 요구사항 분석

### 1.1 필수 구현

| 영역 | 기능 | 비고 |
|------|------|------|
| Backend | 멤버십 종류 CRUD API | 어드민용 |
| Backend | 유저 멤버십 할당/삭제 API | 어드민 + 결제 Mock |
| Backend | 멤버십 만료 시 접근 차단 | before_action |
| Backend | 시드 데이터 (멤버십 종류) | seeds.rb |
| Frontend | 홈: 현재 멤버십 현황 조회 | |
| Frontend | 홈: 멤버십 구매 UI | 결제 Mock 연동 |
| Frontend | 대화 화면: 멤버십 권한 체크 후 진입 | |
| Frontend | 대화 화면: AI 첫 메시지 자동 시작 | TTS |
| Frontend | 대화 화면: 마이크 녹음 + Waveform 시각화 | Web Audio API |
| Frontend | 대화 화면: 답변완료 → STT → LLM → TTS | 전체 파이프라인 |
| 공통 | LLM/STT/TTS 실제 연동 (Mock 금지) | OpenAI |

### 1.2 Optional 구현 (선택: 필수 + 핵심 Optional)

| 기능 | 우선순위 | 이유 |
|------|----------|------|
| SSE Streaming 응답 | 높음 | AI 파이프라인 어필 핵심 |
| VAD (음성 공백 제거) | 높음 | STT 품질 향상 |
| TTS 재생 버튼 (재청취) | 중간 | UX 완성도 |
| Rate Limiting (오남용 방지) | 중간 | 서비스 안정성 |
| PG Mock 결제 API | 중간 | 백엔드 완성도 |
| 대화 세션 DB 저장 API | 중간 | 백엔드 완성도 |
| 네트워크 오류 처리 | 높음 | 서비스 안정성 |

### 1.3 명시적 제외 요구사항

- 실제 PG사 결제 API 연동
- 인증 로직 (로그인/세션)
- 디자인 완성도
- 대화 기록 서버 저장 (클라이언트 세션으로 가능, optional로 구현)

---

## 2. 도메인 모델 분석

### 2.1 핵심 엔티티

```
Membership (멤버십 종류 정의 테이블)
├── 이름 (베이직, 프리미엄 등)
├── 권한 조합 (can_learn, can_converse, can_analyze)
├── 이용기한 (duration_days)
└── 가격 (price_cents - 결제 Mock용)

UserMembership (유저가 보유한 멤버십 인스턴스)
├── user_id (인증 없으므로 단순 정수 식별자)
├── membership_id → Membership
├── 시작일 (started_at)
├── 만료일 (expires_at = started_at + duration_days)
├── 상태 (status: active / expired / cancelled)
└── 부여 방식 (granted_by: purchase / admin)

Conversation (대화 세션 - optional)
├── user_id
├── user_membership_id → UserMembership
└── topic (주제)

Message (대화 메시지 - optional)
├── conversation_id → Conversation
├── role (user / assistant)
└── content (텍스트)
```

### 2.2 권한 체크 로직

```
유저가 /chat 접근 시:
  1. user_id로 UserMembership 조회
  2. status = 'active' AND expires_at > NOW() AND can_converse = true
  3. 조건 불충족 시 → 403 Forbidden (MEMBERSHIP_REQUIRED)
```

### 2.3 리스크: 유저 식별자 (인증 없음)

**문제**: 인증 로직이 제외 요구사항이지만, user_id 없이 멤버십 조회 불가.

**결정**: `X-User-Id` HTTP 헤더로 user_id 전달.
- 프론트엔드에서 localStorage에 user_id 임시 저장 (데모/테스트용)
- 실제 서비스라면 JWT 교체 위치가 명확하도록 `ApplicationController#current_user_id` 메서드로 추상화

---

## 3. AI 파이프라인 분석

### 3.1 전체 플로우

```
[유저 마이크 녹음]
      ↓ MediaRecorder API (WebM/Opus)
[VAD: 공백 구간 제거] (optional)
      ↓ 오디오 Blob
[답변완료 버튼]
      ↓ multipart/form-data
POST /api/v1/ai/stt
      ↓ OpenAI Whisper API
[유저 텍스트 반환]
      ↓ text/event-stream (SSE)
POST /api/v1/ai/chat
      ↓ OpenAI GPT-4o Streaming
[AI 텍스트 청크 → 프론트 실시간 표시]
      ↓ 전체 텍스트 완성 후
POST /api/v1/ai/tts
      ↓ OpenAI TTS API
[오디오 binary → 자동 재생]
```

### 3.2 지연 시간 분석 (최적화 포인트)

| 단계 | 예상 지연 | 최적화 방법 |
|------|-----------|-------------|
| STT (Whisper) | 1~3초 | VAD로 오디오 크기 축소 |
| LLM (GPT-4o) | 2~5초 | **SSE Streaming** → 첫 토큰 즉시 표시 |
| TTS | 1~2초 | LLM 응답 완성 후 즉시 요청 |
| 합계 | 4~10초 | 스트리밍으로 체감 지연 2~3초로 감소 |

### 3.3 오디오 포맷 결정

- 녹음: `audio/webm;codecs=opus` (브라우저 기본 MediaRecorder)
- STT 입력: Whisper는 webm 지원 → 포맷 변환 불필요
- TTS 출력: `audio/mpeg` (mp3) → `AudioContext.decodeAudioData()` 재생

### 3.4 SSE Streaming 구현 방식

```ruby
# Rails ActionController::Live 사용
class Api::V1::Ai::ChatController < ApplicationController
  include ActionController::Live

  def create
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'

    chat_service.stream(messages) do |chunk|
      response.stream.write("data: #{chunk.to_json}\n\n")
    end
  ensure
    response.stream.close
  end
end
```

```typescript
// Next.js: fetch + ReadableStream으로 SSE 소비
const response = await fetch('/api/v1/ai/chat', { method: 'POST', body: ... })
const reader = response.body!.getReader()
// chunk 단위로 텍스트 업데이트
```

---

## 4. 기술 스택 적합성 검토

### 4.1 Rails 7 API-only

| 항목 | 검토 결과 |
|------|-----------|
| ActionController::Live (SSE) | 지원. Puma 멀티스레드 필수 |
| ruby-openai gem | 스트리밍 지원 확인 (v7.x) |
| rack-attack | Rate Limiting 라이브러리, 표준적 |
| PostgreSQL + pg gem | 표준 조합 |
| RSpec + FactoryBot | 테스트 표준 |

**주의**: ActionController::Live + Puma 사용 시 `config/puma.rb`에서 스레드 수 설정 필요.

### 4.2 Next.js 14 App Router

| 항목 | 검토 결과 |
|------|-----------|
| fetch API + ReadableStream | SSE 소비 가능, EventSource보다 유연 |
| MediaRecorder API | 최신 브라우저 전체 지원 |
| Web Audio API (AudioContext) | Waveform 시각화, TTS 재생 |
| Server Components | 멤버십 조회 등 초기 데이터에 활용 가능 |
| Tailwind CSS v3 | 빠른 UI 구성 |

**주의**: AudioContext는 브라우저 당 최대 6개 → `useRef`로 단일 인스턴스 유지 필수.

### 4.3 Docker Compose 구성

```yaml
services:
  db:        # PostgreSQL 15
  backend:   # Rails 7 (port 3001)
  frontend:  # Next.js 14 (port 3000)
```

---

## 5. 의존 관계 지도

```
docker-compose.yml
    ├── PostgreSQL ← backend (DATABASE_URL)
    ├── backend (Rails) ← frontend (NEXT_PUBLIC_API_URL)
    └── backend ← OpenAI API (OPENAI_API_KEY)

데이터 흐름:
Frontend (Next.js)
    → X-User-Id 헤더 포함 요청
    → Rails API
        → Membership/UserMembership (PostgreSQL)
        → OpenAI API (STT/Chat/TTS)
    ← JSON / SSE / Binary 응답
```

---

## 6. 리스크 목록

| 리스크 | 심각도 | 대응 방안 |
|--------|--------|-----------|
| OpenAI API 지연 > 10초 | 높음 | SSE로 체감 지연 감소, 타임아웃 30초 설정 |
| AudioContext 브라우저 제한 | 중간 | useRef 단일 인스턴스 패턴 |
| ActionController::Live + Puma 스레드 | 중간 | puma.rb threads 설정 (min:5, max:5) |
| 마이크 권한 거부 | 낮음 | 에러 UI + 안내 메시지 |
| user_id 위조 가능 | 낮음 | 과제 범위(인증 제외)로 수용, 코드에 주석으로 명시 |
| SSE 연결 누수 (FE) | 중간 | useEffect cleanup에서 reader.cancel() 호출 |

---

## 7. 외부 의존성 목록

| 의존성 | 버전 | 용도 |
|--------|------|------|
| ruby-openai | ~> 7.0 | STT/Chat/TTS OpenAI 호출 |
| pg | ~> 1.5 | PostgreSQL 어댑터 |
| rack-attack | ~> 6.7 | Rate Limiting |
| rack-cors | ~> 2.0 | CORS 설정 |
| rspec-rails | ~> 6.0 | 테스트 프레임워크 |
| factory_bot_rails | ~> 6.4 | 테스트 픽스처 |
| @types/react | ^18 | TypeScript |
| msw | ^2.0 | 프론트 API Mock |
| @testing-library/react | ^14 | 컴포넌트 테스트 |

---

## 8. 결론

현재 코드베이스 없음 (신규 프로젝트). 기존 패턴 재사용 불가 → 전체 신규 설계.

**설계 원칙 3가지:**
1. **AI 파이프라인 최우선**: SSE Streaming, VAD, 오디오 재생 UX 완성도
2. **멤버십 도메인 단순화**: Membership(종류) + UserMembership(인스턴스) 2-테이블 구조
3. **테스트 가능성**: 모든 OpenAI 호출은 Service Object 안에, Controller는 얇게

→ **plan.md 작성으로 진행**
