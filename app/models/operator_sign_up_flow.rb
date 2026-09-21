# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_sign_up_flows
# Database name: org_ticket
#
#  id           :bigint           not null, primary key
#  completed_at :datetime
#  discard_at :datetime         default(Infinity), not null
#  expires_at   :datetime         not null
#  issued_at    :datetime         not null
#  nonce_digest :string           not null
#  purge_eligible_at    :datetime         default(Infinity), not null
#  return_to    :text
#  state        :string           not null
#  step         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  principal_id :bigint
#  public_id    :string(21)       not null
#  status_id    :bigint           default(10), not null
#  token_id     :bigint
#
# Indexes
#
#  index_operator_sign_up_flows_on_discard_at  (discard_at)
#  index_operator_sign_up_flows_on_expires_at    (expires_at)
#  index_operator_sign_up_flows_on_principal_id  (principal_id)
#  index_operator_sign_up_flows_on_public_id     (public_id) UNIQUE
#  index_operator_sign_up_flows_on_state         (state)
#  index_operator_sign_up_flows_on_status_id     (status_id)
#  index_operator_sign_up_flows_on_token_id      (token_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => operator_sign_up_flow_statuses.id)
#  fk_rails_...  (token_id => operator_tokens.id) ON DELETE => cascade
#
class OperatorSignUpFlow < OrgTicketRecord
  include SignFlow
  include FlowSignUp

  STATUS_MODEL = OperatorSignUpFlowStatus
  STATUSES = {
    "STARTED" => STATUS_MODEL::STARTED,
    "CONTACT_PENDING" => STATUS_MODEL::CONTACT_PENDING,
    "CREDENTIAL_PENDING" => STATUS_MODEL::CREDENTIAL_PENDING,
    "CHECKPOINT_PENDING" => STATUS_MODEL::CHECKPOINT_PENDING,
    "COMPLETED" => STATUS_MODEL::COMPLETED,
  }.freeze
  STATUS_NAMES = STATUSES.invert.freeze
  STATUS_IDS = STATUSES.values.freeze
  STEPS = %w(start contact credential checkpoint completed).freeze
  TRANSITIONS = {
    STATUS_MODEL::STARTED => [
      STATUS_MODEL::CONTACT_PENDING,
      STATUS_MODEL::CREDENTIAL_PENDING,
      STATUS_MODEL::CHECKPOINT_PENDING,
      STATUS_MODEL::COMPLETED,
    ],
    STATUS_MODEL::CONTACT_PENDING => [
      STATUS_MODEL::CREDENTIAL_PENDING,
      STATUS_MODEL::CHECKPOINT_PENDING,
      STATUS_MODEL::COMPLETED,
    ],
    STATUS_MODEL::CREDENTIAL_PENDING => [STATUS_MODEL::CHECKPOINT_PENDING, STATUS_MODEL::COMPLETED],
    STATUS_MODEL::CHECKPOINT_PENDING => [STATUS_MODEL::COMPLETED],
    STATUS_MODEL::COMPLETED => [],
  }.freeze

  belongs_to :token, class_name: "OperatorToken"
  belongs_to :status, class_name: "OperatorSignUpFlowStatus"
end
