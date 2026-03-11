# Backend Engineer Plan: Phase 2 — 멤버십 도메인 구현

> 작성일: 2026-03-11
> 근거: architect/plan.md Phase 2 + backend_engineer/research.md
> 상태: 구현 진행 중

---

## 구현 파일 목록 (순서대로)

1. `db/migrate/YYYYMMDD_create_memberships.rb`
2. `db/migrate/YYYYMMDD_create_user_memberships.rb`
3. `app/models/membership.rb`
4. `app/models/user_membership.rb`
5. `spec/factories/memberships.rb`
6. `spec/factories/user_memberships.rb`
7. `app/controllers/concerns/membership_authorization.rb`
8. `app/controllers/application_controller.rb`
9. `app/blueprints/membership_blueprint.rb`
10. `app/blueprints/user_membership_blueprint.rb`
11. `app/controllers/api/v1/memberships_controller.rb`
12. `app/controllers/api/v1/user_memberships_controller.rb`
13. `config/routes.rb`
14. `db/seeds.rb`
15. `spec/models/membership_spec.rb`
16. `spec/models/user_membership_spec.rb`
17. `spec/requests/api/v1/memberships_spec.rb`
18. `spec/requests/api/v1/user_memberships_spec.rb`

---

## API 스펙

### GET /api/v1/memberships
```json
// 200 OK
{ "data": [{ "id": 1, "name": "베이직", "can_learn": true, "can_converse": false, "can_analyze": false, "duration_days": 30, "price_cents": 129000 }] }
```

### POST /api/v1/memberships
```json
// Request
{ "name": "프리미엄", "can_learn": true, "can_converse": true, "can_analyze": true, "duration_days": 60, "price_cents": 219000 }
// 201 Created
{ "data": { Membership } }
// 422 Unprocessable Entity
{ "error": { "code": "VALIDATION_ERROR", "message": "...", "details": [...] } }
```

### DELETE /api/v1/memberships/:id
```json
// 204 No Content
// 404 Not Found
{ "error": { "code": "NOT_FOUND", "message": "Membership not found." } }
```

### GET /api/v1/user_memberships/current
```json
// Header: X-User-Id: 1
// 200 OK (활성 멤버십 있음)
{ "data": { "id": 1, "user_id": 1, "membership": { Membership }, "started_at": "...", "expires_at": "...", "status": "active", "granted_by": "purchase" } }
// 200 OK (없음)
{ "data": null }
```

### POST /api/v1/user_memberships
```json
// Request (어드민)
{ "user_id": 1, "membership_id": 1, "started_at": "2026-03-11T00:00:00Z" }
// 201 Created
{ "data": { UserMembership } }
```

### DELETE /api/v1/user_memberships/:id
```json
// 204 No Content
```

---

## DB DDL 요약

### memberships
- name (string, NOT NULL), can_learn/can_converse/can_analyze (boolean, default: false)
- duration_days (integer, NOT NULL), price_cents (integer, NOT NULL)
- description (text, nullable)

### user_memberships
- user_id (integer, NOT NULL, indexed)
- membership_id (integer, NOT NULL, FK → memberships.id)
- started_at, expires_at (datetime, NOT NULL)
- status (string, default: 'active') — active / expired / cancelled
- granted_by (string, default: 'purchase') — purchase / admin
- 복합 인덱스: (user_id, status), expires_at

---

## 핵심 비즈니스 로직

### UserMembership 스코프
```ruby
scope :active, -> { where(status: 'active').where('expires_at > ?', Time.current) }
scope :for_user, ->(user_id) { where(user_id: user_id) }
```

### MembershipAuthorization concern
- `current_user_id`: X-User-Id 헤더 파싱
- `current_user_membership`: user_id로 활성 멤버십 조회
- `require_conversation_membership`: 대화 권한 체크 before_action

### 만료 처리
- `expires_at` 컬럼 비교로 실시간 체크 (Background Job 미사용)
- status 컬럼은 참고용 (실제 만료 판단은 expires_at > NOW())

---

## TODO (구현 체크리스트)

- [x] plan.md 작성
- [x] Migration: memberships
- [x] Migration: user_memberships
- [x] Model: Membership
- [x] Model: UserMembership
- [ ] Factory: memberships ← 가이드 완료, 파일 생성 대기
- [ ] Factory: user_memberships ← 가이드 완료, 파일 생성 대기
- [ ] Concern: MembershipAuthorization ← 가이드 완료, 파일 생성 대기
- [ ] ApplicationController ← 가이드 완료, 파일 생성 대기
- [ ] Blueprint: Membership, UserMembership ← 가이드 완료, 파일 생성 대기
- [ ] Controller: MembershipsController ← 가이드 완료, 파일 생성 대기
- [ ] Controller: UserMembershipsController ← 가이드 완료, 파일 생성 대기
- [ ] Routes ← 가이드 완료, 파일 생성 대기
- [ ] Seeds ← 가이드 완료, 파일 생성 대기
- [ ] RSpec: membership_spec ← 가이드 완료, 파일 생성 대기
- [ ] RSpec: user_membership_spec ← 가이드 완료, 파일 생성 대기
- [ ] RSpec: memberships_spec (request) ← 가이드 완료, 파일 생성 대기
- [ ] RSpec: user_memberships_spec (request) ← 가이드 완료, 파일 생성 대기
- [ ] bundle exec rails db:migrate
- [ ] bundle exec rails db:seed
- [ ] bundle exec rspec spec/models spec/requests/api/v1
