# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_sign_up_flows
# Database name: app_ticket
#
#  id                              :bigint           not null, primary key
#  cancelled_at                    :datetime
#  checkpoint_version              :integer          default(0), not null
#  cleanup_attempted_at            :datetime
#  cleanup_attempts_count          :integer          default(0), not null
#  cleanup_completed_at            :datetime
#  cleanup_error_code              :string
#  completed_at                    :datetime
#  completed_requirements          :jsonb            not null
#  discard_at                    :datetime         default(Infinity), not null
#  entry_method                    :string           not null
#  expires_at                      :datetime         not null
#  failed_at                       :datetime
#  issued_at                       :datetime         not null
#  nonce_digest                    :string           not null
#  pending_contact_type            :string
#  purge_eligible_at                       :datetime         default(Infinity), not null
#  return_to                       :text
#  social_provider                 :string
#  state                           :string           not null
#  step                            :string           not null
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  cleanup_status_id               :bigint           default(10), not null
#  pending_contact_id              :bigint
#  pending_passkey_registration_id :bigint
#  principal_id                    :bigint
#  public_id                       :string(21)       not null
#  status_id                       :bigint           default(10), not null
#  token_id                        :bigint
#
# Indexes
#
#  index_client_sign_up_flows_on_cleanup_status_id_and_purge_eligible_at  (cleanup_status_id,purge_eligible_at)
#  index_client_sign_up_flows_on_discard_at                     (discard_at)
#  index_client_sign_up_flows_on_expires_at                       (expires_at)
#  index_client_sign_up_flows_on_pending_contact_id               (pending_contact_id)
#  index_client_sign_up_flows_on_pending_passkey_registration_id  (pending_passkey_registration_id)
#  index_client_sign_up_flows_on_principal_id                     (principal_id)
#  index_client_sign_up_flows_on_public_id                        (public_id) UNIQUE
#  index_client_sign_up_flows_on_state                            (state)
#  index_client_sign_up_flows_on_status_id_and_expires_at         (status_id,expires_at)
#  index_client_sign_up_flows_on_token_id                         (token_id)
#
# Foreign Keys
#
#  fk_rails_...  (cleanup_status_id => client_sign_up_flow_cleanup_statuses.id)
#  fk_rails_...  (status_id => client_sign_up_flow_statuses.id) ON DELETE => restrict
#  fk_rails_...  (token_id => client_tokens.id) ON DELETE => restrict
#
class ClientSignUpFlow < AppTicketRecord
  include SignFlow
  include FlowSignUp
  include SignUpFlowTicket

  STATUS_MODEL = ClientSignUpFlowStatus
  ENTRY_METHODS = %w(email telephone google apple).freeze
  SOCIAL_ENTRY_METHODS = %w(google apple).freeze
  STATUSES = {
    "STARTED" => STATUS_MODEL::STARTED,
    "CONTACT_PENDING" => STATUS_MODEL::CONTACT_PENDING,
    "CREDENTIAL_PENDING" => STATUS_MODEL::CREDENTIAL_PENDING,
    "CONTACT_VERIFIED" => STATUS_MODEL::CONTACT_VERIFIED,
    "SOCIAL_CALLBACK_PENDING" => STATUS_MODEL::SOCIAL_CALLBACK_PENDING,
    "GUARDRAIL_PENDING" => STATUS_MODEL::GUARDRAIL_PENDING,
    "CHECKPOINT_PENDING" => STATUS_MODEL::CHECKPOINT_PENDING,
    "FINALIZING" => STATUS_MODEL::FINALIZING,
    "COMPLETED" => STATUS_MODEL::COMPLETED,
    "FAILED" => STATUS_MODEL::FAILED,
    "EXPIRED" => STATUS_MODEL::EXPIRED,
    "CANCELLED" => STATUS_MODEL::CANCELLED,
    "HALTED" => STATUS_MODEL::HALTED,
  }.freeze
  HISTORICAL_STATUSES = {
    "FINALIZED" => STATUS_MODEL::FINALIZED,
    "SIGN_IN_HANDOFF_PENDING" => STATUS_MODEL::SIGN_IN_HANDOFF_PENDING,
  }.freeze
  STATUS_NAMES = STATUSES.merge(HISTORICAL_STATUSES).invert.freeze
  STATUS_IDS = (STATUSES.values + HISTORICAL_STATUSES.values).freeze
  STEPS = %w(start contact credential contact_verified social_callback guardrail checkpoint finalizing completed failed
             expired cancelled halted).freeze
  TRANSITIONS = {
    STATUS_MODEL::STARTED => [
      STATUS_MODEL::CONTACT_PENDING,
      STATUS_MODEL::CREDENTIAL_PENDING,
      STATUS_MODEL::SOCIAL_CALLBACK_PENDING,
      STATUS_MODEL::EXPIRED,
      STATUS_MODEL::CANCELLED,
      STATUS_MODEL::HALTED,
    ],
    STATUS_MODEL::CONTACT_PENDING => [
      STATUS_MODEL::CREDENTIAL_PENDING,
      STATUS_MODEL::CONTACT_VERIFIED,
      STATUS_MODEL::EXPIRED,
      STATUS_MODEL::CANCELLED,
      STATUS_MODEL::HALTED,
    ],
    STATUS_MODEL::CREDENTIAL_PENDING => [
      STATUS_MODEL::CONTACT_VERIFIED,
      STATUS_MODEL::EXPIRED,
      STATUS_MODEL::CANCELLED,
      STATUS_MODEL::HALTED,
    ],
    STATUS_MODEL::CONTACT_VERIFIED => [
      STATUS_MODEL::GUARDRAIL_PENDING,
      STATUS_MODEL::EXPIRED,
      STATUS_MODEL::CANCELLED,
      STATUS_MODEL::HALTED,
    ],
    STATUS_MODEL::SOCIAL_CALLBACK_PENDING => [
      STATUS_MODEL::CONTACT_VERIFIED,
      STATUS_MODEL::GUARDRAIL_PENDING,
      STATUS_MODEL::CHECKPOINT_PENDING,
      STATUS_MODEL::EXPIRED,
      STATUS_MODEL::CANCELLED,
      STATUS_MODEL::HALTED,
    ],
    STATUS_MODEL::GUARDRAIL_PENDING => [
      STATUS_MODEL::CHECKPOINT_PENDING,
      STATUS_MODEL::EXPIRED,
      STATUS_MODEL::CANCELLED,
      STATUS_MODEL::HALTED,
    ],
    STATUS_MODEL::CHECKPOINT_PENDING => [
      STATUS_MODEL::FINALIZING,
      STATUS_MODEL::EXPIRED,
      STATUS_MODEL::CANCELLED,
      STATUS_MODEL::HALTED,
    ],
    STATUS_MODEL::FINALIZING => [STATUS_MODEL::COMPLETED, STATUS_MODEL::EXPIRED, STATUS_MODEL::CANCELLED, STATUS_MODEL::HALTED],
    STATUS_MODEL::COMPLETED => [],
    STATUS_MODEL::FAILED => [],
    STATUS_MODEL::EXPIRED => [],
    STATUS_MODEL::CANCELLED => [],
    STATUS_MODEL::HALTED => [],
  }.freeze

  belongs_to :token, class_name: "ClientToken"
  belongs_to :status, class_name: "ClientSignUpFlowStatus"
  belongs_to :cleanup_status, class_name: "ClientSignUpFlowCleanupStatus", optional: false

  validates :social_provider, inclusion: { in: SOCIAL_ENTRY_METHODS }, allow_nil: true

  def self.cleanup_status_class
    ClientSignUpFlowCleanupStatus
  end
end
