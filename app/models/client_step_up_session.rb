# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_step_up_sessions
# Database name: app_ticket
#
#  id            :bigint           not null, primary key
#  attempt_count :integer          default(0), not null
#  discard_at  :datetime         default(Infinity), not null
#  method        :string
#  purge_eligible_at     :datetime         default(Infinity), not null
#  return_to     :text             not null
#  scope         :string           not null
#  status        :string           not null
#  verified_at   :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_token_id :bigint           not null
#
# Indexes
#
#  index_client_step_up_sessions_on_user_token_id  (user_token_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_token_id => client_tokens.id) ON DELETE => cascade
#
class ClientStepUpSession < AppTicketRecord
  include Retainable
  include StepUpSessionConsumable

  STATUSES = %w(PENDING VERIFIED).freeze
  METHODS = %w(passkey totp email_otp).freeze

  belongs_to :user_token, class_name: "ClientToken", inverse_of: :step_up_session

  validates :scope, presence: true
  validates :return_to, presence: true
  validates :user_token_id, uniqueness: true
  validates :method, inclusion: { in: METHODS }, allow_nil: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :discard_at, presence: true
  validates :attempt_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :for_user_token, ->(user_token) { where(user_token_id: user_token.id) }
  scope :recent_first, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: "PENDING") }

  def expired?
    discard_at <= Time.current
  end
end
