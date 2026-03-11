class Membership < ApplicationRecord
  has_many :user_memberships, dependent: :restrict_with_error

  VALID_NAME_PATTERN = /\A.{1,100}\z/

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :duration_days, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :price_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :can_learn, :can_converse, :can_analyze, inclusion: { in: [ true, false ] }

  scope :ordered, -> { order(:price_cents) }
end
