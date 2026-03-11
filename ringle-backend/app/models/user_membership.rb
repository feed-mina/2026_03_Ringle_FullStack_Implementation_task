class UserMembership < ApplicationRecord
  belongs_to :membership

  STATUSES = %w[active expired cancelled].freeze
  GRANTED_BY = %w[purchase admin].freeze

  validates :user_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :started_at, :expires_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :granted_by, inclusion: { in: GRANTED_BY }
  validate :expires_at_after_started_at

  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :active, -> { where(status: "active").where("expires_at > ?", Time.current) }
  scope :by_latest, -> { order(created_at: :desc) }

  def expired?
    expires_at <= Time.current
  end

  def active?
    status == "active" && !expired?
  end

  def can_converse?
    membership.can_converse
  end

  def can_learn?
    membership.can_learn
  end

  def can_analyze?
    membership.can_analyze
  end

  private

  def expires_at_after_started_at
    return unless started_at && expires_at

    errors.add(:expires_at, "must be after started_at") if expires_at <= started_at
  end
end
