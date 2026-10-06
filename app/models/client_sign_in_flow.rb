# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_sign_in_flows
# Database name: app_ticket
#
#  id                    :bigint           not null, primary key
#  completed_at          :datetime
#  discard_at          :datetime         default(Infinity), not null
#  expires_at            :datetime         not null
#  issued_at             :datetime         not null
#  nonce_digest          :string           not null
#  purge_eligible_at             :datetime         default(Infinity), not null
#  return_to             :text
#  selector_completed_at :datetime
#  session_issued_at     :datetime
#  state_id              :bigint           default(10), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  principal_id          :bigint
#  public_id             :string(21)       not null
#  selected_persona_id   :bigint
#  selected_region_id    :bigint
#  token_id              :bigint
#
# Indexes
#
#  index_client_sign_in_flows_on_discard_at         (discard_at)
#  index_client_sign_in_flows_on_expires_at           (expires_at)
#  index_client_sign_in_flows_on_principal_id         (principal_id)
#  index_client_sign_in_flows_on_public_id            (public_id) UNIQUE
#  index_client_sign_in_flows_on_selected_persona_id  (selected_persona_id)
#  index_client_sign_in_flows_on_selected_region_id   (selected_region_id)
#  index_client_sign_in_flows_on_state_id             (state_id)
#  index_client_sign_in_flows_on_token_id             (token_id)
#
# Foreign Keys
#
#  fk_rails_...  (state_id => client_sign_in_flow_states.id)
#  fk_rails_...  (token_id => client_tokens.id) ON DELETE => cascade
#
class ClientSignInFlow < AppTicketRecord
  include SignInFlow
  include FlowSignIn
  include LocalAuthenticationResultDelivery

  STATE_MODEL = ClientSignInFlowState
  STATES = {
    "PRIMARY_PENDING" => STATE_MODEL::PRIMARY_PENDING,
    "MFA_PENDING" => STATE_MODEL::MFA_PENDING,
    "GUARDRAIL_PENDING" => STATE_MODEL::GUARDRAIL_PENDING,
    "SESSION_ISSUANCE_PENDING" => STATE_MODEL::SESSION_ISSUANCE_PENDING,
    "CHECKPOINT_PENDING" => STATE_MODEL::CHECKPOINT_PENDING,
    "SELECTOR_PENDING" => STATE_MODEL::SELECTOR_PENDING,
    "COMPLETED" => STATE_MODEL::COMPLETED,
    "FAILED" => STATE_MODEL::FAILED,
    "EXPIRED" => STATE_MODEL::EXPIRED,
    "CANCELLED" => STATE_MODEL::CANCELLED,
    "HALTED" => STATE_MODEL::HALTED,
  }.freeze
  HISTORICAL_STATES = {
    "SESSION_LIMIT_PENDING" => STATE_MODEL::SESSION_LIMIT_PENDING,
    "DASHBOARD_PENDING" => STATE_MODEL::DASHBOARD_PENDING,
    "RETURN_PENDING" => STATE_MODEL::RETURN_PENDING,
  }.freeze
  STATE_NAMES = STATES.merge(HISTORICAL_STATES).invert.freeze
  STATE_IDS = (STATES.values + HISTORICAL_STATES.values).freeze
  TRANSITIONS = {
    STATE_MODEL::PRIMARY_PENDING => [
      STATE_MODEL::MFA_PENDING,
      STATE_MODEL::GUARDRAIL_PENDING,
      STATE_MODEL::EXPIRED, STATE_MODEL::CANCELLED, STATE_MODEL::HALTED,
    ],
    STATE_MODEL::MFA_PENDING => [
      STATE_MODEL::GUARDRAIL_PENDING,
      STATE_MODEL::EXPIRED, STATE_MODEL::CANCELLED, STATE_MODEL::HALTED,
    ],
    STATE_MODEL::GUARDRAIL_PENDING => [STATE_MODEL::CHECKPOINT_PENDING, STATE_MODEL::EXPIRED, STATE_MODEL::CANCELLED, STATE_MODEL::HALTED],
    STATE_MODEL::CHECKPOINT_PENDING => [STATE_MODEL::SELECTOR_PENDING, STATE_MODEL::EXPIRED, STATE_MODEL::CANCELLED, STATE_MODEL::HALTED],
    STATE_MODEL::SELECTOR_PENDING => [STATE_MODEL::SESSION_ISSUANCE_PENDING, STATE_MODEL::EXPIRED,
                                      STATE_MODEL::CANCELLED, STATE_MODEL::HALTED,],
    STATE_MODEL::SESSION_ISSUANCE_PENDING => [STATE_MODEL::COMPLETED, STATE_MODEL::EXPIRED, STATE_MODEL::CANCELLED, STATE_MODEL::HALTED],
    STATE_MODEL::COMPLETED => [],
    STATE_MODEL::FAILED => [],
    STATE_MODEL::EXPIRED => [],
    STATE_MODEL::CANCELLED => [],
    STATE_MODEL::HALTED => [],
  }.freeze

  belongs_to :token, class_name: "ClientToken"
  belongs_to :state, class_name: "ClientSignInFlowState"
  belongs_to :principal, class_name: "Client", optional: true
end
