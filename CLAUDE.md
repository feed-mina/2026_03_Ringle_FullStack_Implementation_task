# CLAUDE.md
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Global Workflow Rules

**Always do:**
- 파일 생성/편집을 직접하지 않고 가이드 후 research에 기록
- 커밋 전 항상 테스트 실행
- 스타일 가이드의 네이밍 컨벤션 항상 준수
- 오류는 항상 모니터링 서비스에 로깅

**Ask first:**
- 데이터베이스 스키마 수정 전 (테이블 컬럼 추가/변경/삭제, 인덱스 변경 등)
- 새 의존성 추가 전
- CI/CD 설정 변경 전

**Never do:**
- 시크릿이나 API 키 절대 커밋 금지
- `node_modules/`나 `vendor/` 절대 편집 금지
- 명시적 승인 없이 실패하는 테스트 제거 금지
- 폴더/파일 생성이 필요하다면 우선 .ai 폴더 안에서 생성 후 plan에 필요한 폴더 위치를 설명


## Project Overview

Client - Web은 TypeScript와 React, Backend는 Ruby on Rails를 사용
링글 AI 튜터는 LLM API를 통해 대화형으로 영어 학습을 도와주는 앱입니다. 간
단한 멤버십 기능을 이용해 구매할 수 있는 서비스를 제공합니다. 멤버십을 가진
사용자는 AI와 음성으로 대화할 수 있습니다.
디테일한 디자인과 제외되는 요구사항을 빼면, 실제로 회사에서 서비스용으로 사용하는 앱을 만든다고 가정해야 하며, 적절하게 작동하도록 해야 합니다. 퀄리티 있는 테스트 코드를 반드시 작성해주세요
## Repository Structure

 

## Commands

### Frontend (`ringle-frontend/`)
```bash
npm run dev       # Dev server
npm run build     # Production build
npm run lint      # ESLint
npm run test      # Jest (all tests in tests/**)
npx jest tests/path/to/file.test.tsx  # Single test file
npx playwright test  # E2E tests
```

### Backend (`ringle-backend/`)


### Local Infrastructure

## Architecture

### Data Flow

### Key Concepts

### Frontend Key Files

### Backend Key Packages

### Testing

