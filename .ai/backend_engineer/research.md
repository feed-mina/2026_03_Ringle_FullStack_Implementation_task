# Backend Engineer Research: 프로젝트 초기 설정 현황

> 작성일: 2026-03-11
> 최종 수정: 2026-03-11
> 상태: Phase 2 구현 가이드 완료 → 파일 생성 및 migrate/seed 실행 대기

---

## 1. 현재 구현 현황

### 1.1 Rails 앱 생성

```bash
rails new ringle-backend --api --database=postgresql --skip-test
```

- Rails 버전: **8.1.2** (architect plan 명세: 7 → 실제 8.1.2 설치됨, API-only 모드 동일)
- 경로: `~/Documents/Development/Personal_Projects/2026/ringle/ringle-backend/`
- **주의**: Windows 한글 경로에서 `LoadError` 발생 → 영문 경로로 이동하여 해결

### 1.2 설치된 Gem 목록

`Gemfile`에 추가된 gem (bundle install 완료):

| Gem | 버전 | 용도 |
|-----|------|------|
| `rack-cors` | ~> 2.0 | CORS 설정 |
| `ruby-openai` | ~> 7.0 | STT/Chat/TTS OpenAI 호출 |
| `rack-attack` | ~> 6.7 | Rate Limiting |
| `blueprinter` | ~> 1.0 | JSON 직렬화 |
| `dotenv-rails` | ~> 3.0 | .env 파일 로드 |
| `rspec-rails` | ~> 7.0 | 테스트 프레임워크 |
| `factory_bot_rails` | ~> 6.4 | 테스트 픽스처 |
| `faker` | ~> 3.0 | 테스트 더미 데이터 |
| `shoulda-matchers` | ~> 6.0 | RSpec 매처 확장 |

### 1.3 완료된 설정 파일

#### `config/initializers/cors.rb`
```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("CORS_ORIGINS", "http://localhost:3000").split(",")
    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ["Authorization"],
      credentials: true
  end
end
```

#### `config/database.yml`
- 모든 자격증명을 환경변수로 관리
- Windows 환경 대응: `host: localhost` 명시 (Unix 소켓 불가)
- 환경변수: `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`

#### `spec/rails_helper.rb`
- shoulda-matchers 설정 (`:rspec` + `:rails` 통합)
- `spec/support/**/*.rb` 자동 require
- transactional fixtures 활성화

#### `spec/support/factory_bot.rb`
```ruby
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
```

#### `.env` (git 미추적)
```
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=1234        # 로컬 개발용
CORS_ORIGINS=http://localhost:3000
OPENAI_API_KEY=         # 미설정 (실제 키 필요)
RAILS_MAX_THREADS=5
```

#### `.env.example` (git 추적)
- 필요한 환경변수 목록 문서화
- `.gitignore`에 `!/.env.example` 예외 추가

### 1.4 데이터베이스 생성 완료

```
ringle_backend_development  ✅
ringle_backend_test         ✅
```

---

## 2. Phase 2 구현 현황

### 2.1 완료된 파일

| 파일 | 상태 | 비고 |
|------|------|------|
| `db/migrate/..._create_memberships.rb` | ✅ 완료 | NULL 제약, unique index |
| `db/migrate/..._create_user_memberships.rb` | ✅ 완료 | FK, 복합 index |
| `app/models/membership.rb` | ✅ 완료 | validation, scopes |
| `app/models/user_membership.rb` | ✅ 완료 | validation, scopes, 헬퍼 메서드 |

### 2.2 생성 가이드 완료 (파일 생성 대기 중)

| 파일 | 비고 |
|------|------|
| `spec/factories/memberships.rb` | :basic, :premium 트레이트 |
| `spec/factories/user_memberships.rb` | :expired, :cancelled, :admin_granted 트레이트 |
| `app/controllers/concerns/membership_authorization.rb` | set_current_user_id, require_user!, require_conversation_membership! |
| `app/controllers/application_controller.rb` | rescue_from RecordNotFound, ParameterMissing |
| `app/blueprints/membership_blueprint.rb` | Blueprinter::Base |
| `app/blueprints/user_membership_blueprint.rb` | membership 연관관계 포함 |
| `app/controllers/api/v1/memberships_controller.rb` | index, create, destroy |
| `app/controllers/api/v1/user_memberships_controller.rb` | current, create, destroy |
| `config/routes.rb` | namespace api > v1, user_memberships/current |
| `db/seeds.rb` | 베이직(129,000), 프리미엄(219,000) |
| `spec/models/membership_spec.rb` | validations, associations, scopes |
| `spec/models/user_membership_spec.rb` | validations, scopes, #active?, custom validation |
| `spec/requests/api/v1/memberships_spec.rb` | GET index, POST create, DELETE destroy |
| `spec/requests/api/v1/user_memberships_spec.rb` | GET current, POST create, DELETE destroy |

### 2.3 미구현 (Phase 3~)

- `app/controllers/api/v1/payments_controller.rb`
- `app/controllers/api/v1/ai/stt_controller.rb`
- `app/controllers/api/v1/ai/chat_controller.rb`
- `app/controllers/api/v1/ai/tts_controller.rb`
- `app/services/openai/stt_service.rb`
- `app/services/openai/chat_service.rb`
- `app/services/openai/tts_service.rb`
- `app/services/membership_service.rb`
- `app/services/payment_service.rb`
- `conversations`, `messages` 테이블 (optional)

---

## 3. Phase 2 파일 내용 가이드

### 3.1 `spec/factories/memberships.rb`

```ruby
FactoryBot.define do
  factory :membership do
    name { "프리미엄" }
    can_learn { true }
    can_converse { true }
    can_analyze { true }
    duration_days { 30 }
    price_cents { 219_000 }
    description { "AI 학습 + 대화 + 분석 모두 이용 가능" }

    trait :basic do
      name { "베이직" }
      can_learn { true }
      can_converse { false }
      can_analyze { false }
      duration_days { 30 }
      price_cents { 129_000 }
      description { "AI 학습만 이용 가능" }
    end

    trait :premium do
      name { "프리미엄" }
      can_learn { true }
      can_converse { true }
      can_analyze { true }
      duration_days { 30 }
      price_cents { 219_000 }
    end
  end
end
```

### 3.2 `spec/factories/user_memberships.rb`

```ruby
FactoryBot.define do
  factory :user_membership do
    user_id { 1 }
    association :membership
    started_at { Time.current }
    expires_at { 30.days.from_now }
    status { "active" }
    granted_by { "purchase" }

    trait :expired do
      started_at { 60.days.ago }
      expires_at { 30.days.ago }
      status { "expired" }
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :admin_granted do
      granted_by { "admin" }
    end
  end
end
```

### 3.3 `app/controllers/concerns/membership_authorization.rb`

```ruby
module MembershipAuthorization
  extend ActiveSupport::Concern

  included do
    before_action :set_current_user_id
  end

  private

  def set_current_user_id
    @current_user_id = request.headers["X-User-Id"]&.to_i
  end

  def current_user_id
    @current_user_id
  end

  def current_user_membership
    return nil unless current_user_id.present?

    @current_user_membership ||= UserMembership
      .for_user(current_user_id)
      .active
      .includes(:membership)
      .by_latest
      .first
  end

  def require_user!
    return if current_user_id.present?

    render json: { error: { code: "MISSING_USER_ID", message: "X-User-Id 헤더가 필요합니다." } },
           status: :bad_request
  end

  def require_conversation_membership!
    require_user!
    return if performed?

    unless current_user_membership&.can_converse?
      render json: { error: { code: "MEMBERSHIP_REQUIRED", message: "대화 멤버십이 필요합니다." } },
             status: :forbidden
    end
  end
end
```

### 3.4 `app/controllers/application_controller.rb`

```ruby
class ApplicationController < ActionController::API
  include MembershipAuthorization

  rescue_from ActiveRecord::RecordNotFound do |e|
    render json: { error: { code: "NOT_FOUND", message: e.message } }, status: :not_found
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: { code: "BAD_REQUEST", message: e.message } }, status: :bad_request
  end
end
```

### 3.5 `app/blueprints/membership_blueprint.rb`

```ruby
class MembershipBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :can_learn, :can_converse, :can_analyze,
         :duration_days, :price_cents, :description,
         :created_at, :updated_at
end
```

### 3.6 `app/blueprints/user_membership_blueprint.rb`

```ruby
class UserMembershipBlueprint < Blueprinter::Base
  identifier :id

  fields :user_id, :started_at, :expires_at, :status, :granted_by,
         :created_at, :updated_at

  association :membership, blueprint: MembershipBlueprint
end
```

### 3.7 `app/controllers/api/v1/memberships_controller.rb`

```ruby
module Api
  module V1
    class MembershipsController < ApplicationController
      def index
        memberships = Membership.ordered
        render json: { data: MembershipBlueprint.render_as_hash(memberships) }
      end

      def create
        membership = Membership.new(membership_params)
        if membership.save
          render json: { data: MembershipBlueprint.render_as_hash(membership) }, status: :created
        else
          render json: {
            error: {
              code: "VALIDATION_ERROR",
              message: membership.errors.full_messages.join(", "),
              details: membership.errors.as_json
            }
          }, status: :unprocessable_entity
        end
      end

      def destroy
        membership = Membership.find(params[:id])
        membership.destroy!
        head :no_content
      end

      private

      def membership_params
        params.require(:membership).permit(
          :name, :can_learn, :can_converse, :can_analyze,
          :duration_days, :price_cents, :description
        )
      end
    end
  end
end
```

### 3.8 `app/controllers/api/v1/user_memberships_controller.rb`

```ruby
module Api
  module V1
    class UserMembershipsController < ApplicationController
      def current
        require_user!
        return if performed?

        user_membership = UserMembership.for_user(current_user_id).active.includes(:membership).by_latest.first
        render json: { data: user_membership ? UserMembershipBlueprint.render_as_hash(user_membership) : nil }
      end

      def create
        user_membership = UserMembership.new(user_membership_params)
        if user_membership.membership
          user_membership.expires_at = user_membership.started_at + user_membership.membership.duration_days.days
        end

        if user_membership.save
          render json: { data: UserMembershipBlueprint.render_as_hash(user_membership) }, status: :created
        else
          render json: {
            error: {
              code: "VALIDATION_ERROR",
              message: user_membership.errors.full_messages.join(", "),
              details: user_membership.errors.as_json
            }
          }, status: :unprocessable_entity
        end
      end

      def destroy
        user_membership = UserMembership.find(params[:id])
        user_membership.update!(status: "cancelled")
        head :no_content
      end

      private

      def user_membership_params
        params.require(:user_membership).permit(:user_id, :membership_id, :started_at, :granted_by)
      end
    end
  end
end
```

### 3.9 `config/routes.rb`

```ruby
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :memberships, only: [:index, :create, :destroy]

      scope :user_memberships do
        get :current, to: "user_memberships#current"
      end
      resources :user_memberships, only: [:create, :destroy]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
```

### 3.10 `db/seeds.rb`

```ruby
puts "Seeding memberships..."

Membership.find_or_create_by!(name: "베이직") do |m|
  m.can_learn    = true
  m.can_converse = false
  m.can_analyze  = false
  m.duration_days = 30
  m.price_cents   = 129_000
  m.description   = "AI 학습 기능만 이용 가능한 기본 멤버십"
end

Membership.find_or_create_by!(name: "프리미엄") do |m|
  m.can_learn    = true
  m.can_converse = true
  m.can_analyze  = true
  m.duration_days = 30
  m.price_cents   = 219_000
  m.description   = "AI 학습 + 음성 대화 + 분석 모두 이용 가능한 프리미엄 멤버십"
end

puts "Done! #{Membership.count} memberships seeded."
```

### 3.11 `spec/models/membership_spec.rb`

```ruby
require "rails_helper"

RSpec.describe Membership, type: :model do
  describe "validations" do
    subject { build(:membership) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
    it { should validate_presence_of(:duration_days) }
    it { should validate_numericality_of(:duration_days).only_integer.is_greater_than(0) }
    it { should validate_presence_of(:price_cents) }
    it { should validate_numericality_of(:price_cents).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe "associations" do
    it { should have_many(:user_memberships).dependent(:restrict_with_error) }
  end

  describe "scopes" do
    describe ".ordered" do
      it "returns memberships ordered by price_cents ascending" do
        premium = create(:membership, :premium)
        basic   = create(:membership, :basic)
        expect(Membership.ordered).to eq([basic, premium])
      end
    end
  end
end
```

### 3.12 `spec/models/user_membership_spec.rb`

```ruby
require "rails_helper"

RSpec.describe UserMembership, type: :model do
  describe "validations" do
    subject { build(:user_membership) }

    it { should validate_presence_of(:user_id) }
    it { should validate_numericality_of(:user_id).only_integer.is_greater_than(0) }
    it { should validate_presence_of(:started_at) }
    it { should validate_presence_of(:expires_at) }
    it { should validate_inclusion_of(:status).in_array(UserMembership::STATUSES) }
    it { should validate_inclusion_of(:granted_by).in_array(UserMembership::GRANTED_BY) }
  end

  describe "associations" do
    it { should belong_to(:membership) }
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active and non-expired memberships" do
        active    = create(:user_membership)
        expired   = create(:user_membership, :expired)
        cancelled = create(:user_membership, :cancelled)

        expect(UserMembership.active).to include(active)
        expect(UserMembership.active).not_to include(expired, cancelled)
      end
    end

    describe ".for_user" do
      it "returns memberships for the given user_id" do
        um1 = create(:user_membership, user_id: 1)
        um2 = create(:user_membership, user_id: 2)

        expect(UserMembership.for_user(1)).to include(um1)
        expect(UserMembership.for_user(1)).not_to include(um2)
      end
    end
  end

  describe "#active?" do
    it "returns true for active non-expired membership" do
      um = build(:user_membership)
      expect(um.active?).to be true
    end

    it "returns false for expired membership" do
      um = build(:user_membership, :expired)
      expect(um.active?).to be false
    end
  end

  describe "custom validation" do
    it "is invalid when expires_at is before started_at" do
      um = build(:user_membership, started_at: Time.current, expires_at: 1.hour.ago)
      expect(um).not_to be_valid
      expect(um.errors[:expires_at]).to be_present
    end
  end
end
```

### 3.13 `spec/requests/api/v1/memberships_spec.rb`

```ruby
require "rails_helper"

RSpec.describe "Api::V1::Memberships", type: :request do
  describe "GET /api/v1/memberships" do
    it "returns all memberships ordered by price" do
      create(:membership, :basic)
      create(:membership, :premium)

      get "/api/v1/memberships"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"].length).to eq(2)
      expect(json["data"].first["name"]).to eq("베이직")
    end
  end

  describe "POST /api/v1/memberships" do
    let(:valid_params) do
      {
        membership: {
          name: "테스트", can_learn: true, can_converse: false,
          can_analyze: false, duration_days: 30, price_cents: 99_000
        }
      }
    end

    it "creates a membership" do
      post "/api/v1/memberships", params: valid_params

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["name"]).to eq("테스트")
    end

    it "returns validation errors for invalid params" do
      post "/api/v1/memberships", params: { membership: { name: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
    end
  end

  describe "DELETE /api/v1/memberships/:id" do
    it "deletes a membership" do
      membership = create(:membership)

      delete "/api/v1/memberships/#{membership.id}"

      expect(response).to have_http_status(:no_content)
    end

    it "returns 404 for non-existent membership" do
      delete "/api/v1/memberships/99999"

      expect(response).to have_http_status(:not_found)
    end
  end
end
```

### 3.14 `spec/requests/api/v1/user_memberships_spec.rb`

```ruby
require "rails_helper"

RSpec.describe "Api::V1::UserMemberships", type: :request do
  let(:membership) { create(:membership) }

  describe "GET /api/v1/user_memberships/current" do
    context "with active membership" do
      it "returns current active membership" do
        um = create(:user_membership, user_id: 1, membership: membership)

        get "/api/v1/user_memberships/current", headers: { "X-User-Id" => "1" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]["id"]).to eq(um.id)
        expect(json["data"]["membership"]["id"]).to eq(membership.id)
      end
    end

    context "without membership" do
      it "returns null data" do
        get "/api/v1/user_memberships/current", headers: { "X-User-Id" => "99" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]).to be_nil
      end
    end

    context "without X-User-Id header" do
      it "returns 400 bad request" do
        get "/api/v1/user_memberships/current"

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe "POST /api/v1/user_memberships" do
    it "creates a user membership" do
      post "/api/v1/user_memberships",
        params: { user_membership: { user_id: 1, membership_id: membership.id, started_at: Time.current } }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["user_id"]).to eq(1)
    end
  end

  describe "DELETE /api/v1/user_memberships/:id" do
    it "cancels a user membership" do
      um = create(:user_membership, user_id: 1)

      delete "/api/v1/user_memberships/#{um.id}"

      expect(response).to have_http_status(:no_content)
      expect(um.reload.status).to eq("cancelled")
    end
  end
end
```

---

## 3. 설계 결정 사항 (architect plan 기반)

### 3.1 유저 식별자
- 인증 없음 → `X-User-Id` HTTP 헤더로 user_id 전달
- `ApplicationController#current_user_id`로 추상화 (JWT 교체 위치 명확화)

### 3.2 멤버십 권한 체크
```ruby
# before_action으로 AI 엔드포인트 보호
def require_conversation_membership
  unless current_user_membership&.can_converse? && !current_user_membership.expired?
    render json: {
      error: { code: 'MEMBERSHIP_REQUIRED', message: '대화 멤버십이 필요합니다.' }
    }, status: :forbidden
  end
end
```

### 3.3 SSE Streaming (Chat)
- `ActionController::Live` include
- Puma 스레드 설정 필요: `config/puma.rb` threads 5-5

### 3.4 API 응답 표준
```json
// 성공
{ "data": { ... }, "meta": { ... } }

// 실패
{ "error": { "code": "MEMBERSHIP_EXPIRED", "message": "..." } }
```

### 3.5 파일 업로드 제한
- 오디오 파일: 10MB 이하 (STT 엔드포인트)

---

## 4. 리스크 및 주의사항

| 항목 | 내용 |
|------|------|
| OPENAI_API_KEY 미설정 | `.env`에 빈 값 → Phase 2 구현 전 실제 키 필요 |
| Rails 8.1.2 vs plan 7 | ActionController::Live, ruby-openai 호환성 동일 확인 필요 |
| Windows 환경 | 한글 경로 LoadError 경험 → 영문 경로 유지 필수 |
| ActionController::Live + Puma | puma.rb 스레드 설정 필수 (min:5, max:5) |

---

## 5. 다음 단계

### Phase 2 남은 작업
파일 생성 후 아래 명령어 실행:
```bash
bundle exec rails db:migrate
bundle exec rails db:seed
bundle exec rspec spec/models spec/requests/api/v1
```

### Phase 3 (AI 서비스)
1. `config/puma.rb` — threads 5-5 설정 (ActionController::Live 필수)
2. `app/services/openai/stt_service.rb`
3. `app/services/openai/chat_service.rb` (SSE streaming)
4. `app/services/openai/tts_service.rb`
5. `app/controllers/api/v1/ai/stt_controller.rb`
6. `app/controllers/api/v1/ai/chat_controller.rb`
7. `app/controllers/api/v1/ai/tts_controller.rb`
8. `.env`에 `OPENAI_API_KEY` 실제 값 설정 필요
