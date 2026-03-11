# Frontend Engineer Research: 프로젝트 초기 설정 현황

> 작성일: 2026-03-11
> 상태: 초기 환경 구성 완료 → Phase 2 (컴포넌트 구현) 대기

---

## 1. 현재 구현 현황

### 1.1 Next.js 앱 생성

```bash
npx create-next-app@latest ringle-frontend \
  --typescript --tailwind --eslint --app \
  --no-src-dir --import-alias "@/*" \
  --no-react-compiler --no-turbopack
```

- 경로: `~/Documents/Development/Personal_Projects/2026/ringle/ringle-frontend/`
- **버전 차이**: architect plan 명세는 Next.js 14이나, **16.1.6** 설치됨
  - App Router 구조 동일 → 호환 이슈 없음
  - React 버전: **19.2.3** (plan 명세 18 → 19 설치)
  - Tailwind CSS: **v4** (plan 명세 v3 → v4 설치) → 설정 방식 차이 주의

### 1.2 설치된 패키지

#### Dependencies
| 패키지 | 버전 |
|--------|------|
| `next` | 16.1.6 |
| `react` | 19.2.3 |
| `react-dom` | 19.2.3 |

#### DevDependencies
| 패키지 | 버전 | 용도 |
|--------|------|------|
| `jest` | ^30.3.0 | 테스트 러너 |
| `jest-environment-jsdom` | ^30.3.0 | 브라우저 환경 에뮬레이션 |
| `@testing-library/react` | ^16.3.2 | React 컴포넌트 테스트 |
| `@testing-library/jest-dom` | ^6.9.1 | DOM 매처 확장 |
| `@testing-library/user-event` | ^14.6.1 | 사용자 이벤트 시뮬레이션 |
| `@types/jest` | ^30.0.0 | Jest 타입 정의 |
| `msw` | ^2.12.10 | API Mock (MSW v2) |
| `@playwright/test` | ^1.58.2 | E2E 테스트 |
| `typescript` | ^5 | 타입 시스템 |
| `tailwindcss` | ^4 | CSS 유틸리티 |

### 1.3 완료된 설정 파일

#### `next.config.ts`
```typescript
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async rewrites() {
    return [
      {
        source: "/api/:path*",
        destination: `${process.env.BACKEND_URL || "http://localhost:3001"}/api/:path*`,
      },
    ];
  },
};

export default nextConfig;
```
- 프론트엔드에서 `/api/*` 요청 → Next.js가 `localhost:3001`로 프록시
- `BACKEND_URL` 환경변수로 프로덕션 분리 가능

#### `.env.local` (git 미추적)
```
BACKEND_URL=http://localhost:3001
NEXT_PUBLIC_API_URL=http://localhost:3001
NEXT_PUBLIC_USER_ID=1        # 개발용 기본 user_id
```

#### `jest.config.js`
```javascript
const nextJest = require("next/jest");
const createJestConfig = nextJest({ dir: "./" });

const customJestConfig = {
  setupFilesAfterEnv: ["<rootDir>/jest.setup.js"],
  testEnvironment: "jest-environment-jsdom",
  testMatch: ["<rootDir>/tests/**/*.test.{ts,tsx}"],
  testPathIgnorePatterns: ["<rootDir>/node_modules/", "<rootDir>/tests/e2e/"],
  moduleNameMapper: { "^@/(.*)$": "<rootDir>/$1" },
};

module.exports = createJestConfig(customJestConfig);
```

#### `jest.setup.js`
```javascript
import "@testing-library/jest-dom";
import { server } from "./tests/mocks/server";

beforeAll(() => server.listen({ onUnhandledRequest: "error" }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

#### `playwright.config.ts`
- testDir: `./tests/e2e`
- baseURL: `http://localhost:3000`
- webServer: `npm run dev` 자동 시작
- 브라우저: Chromium (단일)

#### `tests/mocks/handlers.ts`
MSW v2 API로 구현된 기본 핸들러:
- `GET /api/v1/user_memberships/current` → 활성 프리미엄 멤버십 mock
- `POST /api/v1/ai/stt` → 텍스트 응답 mock
- `POST /api/v1/ai/chat` → SSE 스트리밍 응답 mock (50ms 간격)
- `POST /api/v1/ai/tts` → 오디오 바이너리 mock
- `POST /api/v1/payments` → 결제 성공 mock

#### `tests/mocks/server.ts`
```typescript
import { setupServer } from "msw/node";
import { handlers } from "./handlers";
export const server = setupServer(...handlers);
```

#### `package.json` scripts
```json
"test": "jest",
"test:watch": "jest --watch",
"test:e2e": "playwright test"
```

---

## 2. 미구현 항목 (Phase 2~)

### App Router 페이지 (전체 미구현)
- `app/page.tsx` — 홈 (멤버십 현황 + 구매)
- `app/chat/page.tsx` — AI 대화 화면 (핵심)
- `app/admin/page.tsx` — 어드민 (멤버십 관리)
- `app/layout.tsx` — 루트 레이아웃 (Providers)

### 핵심 컴포넌트 (전체 미구현)
- `components/chat/AudioRecorder.tsx` — 마이크 녹음 + 답변완료 버튼
- `components/chat/Waveform.tsx` — 오디오 인식 시각화
- `components/chat/ChatMessage.tsx` — AI/유저 메시지 버블 + TTS 재생
- `components/chat/ConversationPanel.tsx` — 대화 목록 + 스트리밍 응답
- `components/membership/MembershipCard.tsx` — 멤버십 현황 카드
- `components/membership/PurchaseModal.tsx` — 결제 모달

### 커스텀 훅 (전체 미구현)
- `hooks/useAudioRecorder.ts` — MediaRecorder API + VAD
- `hooks/useConversation.ts` — 대화 상태 + SSE 스트리밍
- `hooks/useTTS.ts` — TTS 오디오 재생
- `hooks/useMembership.ts` — 멤버십 데이터 + 권한 체크

### API 레이어 (전체 미구현)
- `lib/api.ts` — fetch 래퍼 (baseURL, X-User-Id 헤더, 에러 처리)
- `lib/types.ts` — 공통 타입 (Membership, UserMembership, Message, Conversation)

---

## 3. 설계 결정 사항

### 3.1 API 호출 방식
- 프론트엔드 → `/api/v1/...` (상대 경로)
- Next.js rewrites → `http://localhost:3001/api/v1/...`
- 모든 요청에 `X-User-Id: {userId}` 헤더 포함 (localStorage 저장)

### 3.2 SSE 스트리밍 소비
```typescript
// EventSource 대신 fetch + ReadableStream 사용 (POST 지원)
const response = await fetch('/api/v1/ai/chat', { method: 'POST', body: ... });
const reader = response.body!.getReader();
// 청크 단위 텍스트 업데이트
```

### 3.3 AudioContext 단일 인스턴스
```typescript
// useRef로 단일 인스턴스 유지 (브라우저 최대 6개 제한)
const audioContextRef = useRef<AudioContext | null>(null);
```

### 3.4 MSW v2 주의사항
- `http` (not `rest`) 사용 — MSW v2 API 변경
- Node 환경: `setupServer` from `msw/node`
- 브라우저 E2E: `npx msw init public/` 필요 (서비스 워커)

---

## 4. 버전 불일치 및 주의사항

| 항목 | Plan 명세 | 실제 설치 | 영향 |
|------|-----------|-----------|------|
| Next.js | 14 | 16.1.6 | App Router 동일, 일부 API 차이 가능 |
| React | 18 | 19.2.3 | Server Components, hooks 변경 주의 |
| Tailwind CSS | v3 | v4 | 설정 방식 다름 (`postcss.config.mjs` 사용) |

#### Tailwind CSS v4 주의
- v3: `tailwind.config.js` + `@tailwind` directives
- v4: `postcss.config.mjs` + `@import "tailwindcss"` 방식
- `globals.css`에서 v4 방식으로 임포트 확인 필요

---

## 5. 펜딩 작업

### 즉시 필요
- `npx msw init public/` 실행 (MSW 서비스 워커 초기화)

### Phase 2 구현 순서
1. `lib/types.ts` — 타입 정의
2. `lib/api.ts` — fetch 래퍼 + X-User-Id 헤더
3. `hooks/useMembership.ts` + `MembershipCard.tsx`
4. `app/page.tsx` — 홈 화면
5. `hooks/useAudioRecorder.ts` + `AudioRecorder.tsx` + `Waveform.tsx`
6. `hooks/useConversation.ts` + `ConversationPanel.tsx` + `ChatMessage.tsx`
7. `hooks/useTTS.ts`
8. `app/chat/page.tsx` — AI 대화 화면
9. `components/membership/PurchaseModal.tsx`
10. `app/admin/page.tsx`
