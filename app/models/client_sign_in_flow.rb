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
#  state                 :string           not null
#  step                  :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  principal_id          :bigint
#  public_id             :string(21)       not null
#  selected_persona_id   :bigint
#  selected_region_id    :bigint
#  status_id             :bigint           default(10), not null
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
#  index_client_sign_in_flows_on_state                (state)
#  index_client_sign_in_flows_on_status_id            (status_id)
#  index_client_sign_in_flows_on_token_id             (token_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => client_sign_in_flow_statuses.id)
#  fk_rails_...  (token_id => client_tokens.id) ON DELETE => cascade
#
class ClientSignInFlow < AppTicketRecord
  include SignFlow
  include FlowSignIn
  include LocalAuthenticationResultDelivery

  STATUS_MODEL = ClientSignInFlowStatus
  STATUSES = {
    "PRIMARY_PENDING" => STATUS_MODEL::PRIMARY_PENDING,
    "MFA_PENDING" => STATUS_MODEL::MFA_PENDING,
    "SESSION_LIMIT_PENDING" => STATUS_MODEL::SESSION_LIMIT_PENDING,
    "GUARDRAIL_PENDING" => STATUS_MODEL::GUARDRAIL_PENDING,
    "SESSION_ISSUANCE_PENDING" => STATUS_MODEL::SESSION_ISSUANCE_PENDING,
    "CHECKPOINT_PENDING" => STATUS_MODEL::CHECKPOINT_PENDING,
    "SELECTOR_PENDING" => STATUS_MODEL::SELECTOR_PENDING,
    "DASHBOARD_PENDING" => STATUS_MODEL::DASHBOARD_PENDING,
    "RETURN_PENDING" => STATUS_MODEL::RETURN_PENDING,
    "COMPLETED" => STATUS_MODEL::COMPLETED,
    "FAILED" => STATUS_MODEL::FAILED,
  }.freeze
  STATUS_NAMES = STATUSES.invert.freeze
  STATUS_IDS = STATUSES.values.freeze
  STEPS = %w(primary mfa session_limit guardrail checkpoint selector session_issuance dashboard return_to completed
             failed).freeze
  STEP_BY_STATUS_ID = {
    STATUS_MODEL::PRIMARY_PENDING => "primary",
    STATUS_MODEL::MFA_PENDING => "mfa",
    STATUS_MODEL::SESSION_LIMIT_PENDING => "session_limit",
    STATUS_MODEL::GUARDRAIL_PENDING => "guardrail",
    STATUS_MODEL::SESSION_ISSUANCE_PENDING => "session_issuance",
    STATUS_MODEL::CHECKPOINT_PENDING => "checkpoint",
    STATUS_MODEL::SELECTOR_PENDING => "selector",
    STATUS_MODEL::DASHBOARD_PENDING => "dashboard",
    STATUS_MODEL::RETURN_PENDING => "return_to",
    STATUS_MODEL::COMPLETED => "completed",
    STATUS_MODEL::FAILED => "failed",
  }.freeze
  TRANSITIONS = {
    STATUS_MODEL::PRIMARY_PENDING => [
      STATUS_MODEL::MFA_PENDING,
      STATUS_MODEL::SESSION_LIMIT_PENDING,
      STATUS_MODEL::GUARDRAIL_PENDING,
      STATUS_MODEL::FAILED,
    ],
    STATUS_MODEL::MFA_PENDING => [
      STATUS_MODEL::SESSION_LIMIT_PENDING,
      STATUS_MODEL::GUARDRAIL_PENDING,
      STATUS_MODEL::FAILED,
    ],
    STATUS_MODEL::SESSION_LIMIT_PENDING => [STATUS_MODEL::GUARDRAIL_PENDING, STATUS_MODEL::FAILED],
    STATUS_MODEL::GUARDRAIL_PENDING => [STATUS_MODEL::CHECKPOINT_PENDING, STATUS_MODEL::FAILED],
    STATUS_MODEL::CHECKPOINT_PENDING => [STATUS_MODEL::SELECTOR_PENDING, STATUS_MODEL::FAILED],
    STATUS_MODEL::SELECTOR_PENDING => [STATUS_MODEL::SESSION_ISSUANCE_PENDING, STATUS_MODEL::FAILED],
    STATUS_MODEL::SESSION_ISSUANCE_PENDING => [STATUS_MODEL::SESSION_LIMIT_PENDING, STATUS_MODEL::COMPLETED, STATUS_MODEL::FAILED],
    STATUS_MODEL::DASHBOARD_PENDING => [STATUS_MODEL::RETURN_PENDING, STATUS_MODEL::SESSION_ISSUANCE_PENDING, STATUS_MODEL::FAILED],
    STATUS_MODEL::RETURN_PENDING => [STATUS_MODEL::COMPLETED, STATUS_MODEL::FAILED],
    STATUS_MODEL::COMPLETED => [],
    STATUS_MODEL::FAILED => [],
  }.freeze

  belongs_to :token, class_name: "ClientToken"
  belongs_to :status, class_name: "ClientSignInFlowStatus"
  belongs_to :principal, class_name: "Client", optional: true

  public

  # Base alone advances an authenticated OIDC handoff into canonical issuance.
  # The durable authorization transaction, source claim and ceremony must agree.
  def prepare_secret_oidc_issuance!(authorization_transaction:)
    authorization_transaction.with_lock do
      with_lock do
        now = self.class.database_now
        claim = ClientSecretCredential.find_by(claim_sign_in_flow_ref: public_id, client_id: principal_id)
        ceremony = claim && ClientAuthCeremonySession.lock.find_by(id: claim.claim_ceremony_session_id)
        verify_secret_oidc_transaction!(authorization_transaction, now)
        unless !expired?(now) && token_id.nil? && session_issued_at.nil? &&
            authentication_method == "secret" && authentication_context == "normal"
          raise FlowInvalidTransition, "Secret OIDC flow evidence mismatch"
        end
        unless claim&.claimed_at && claim.consumed_at.nil? && claim.discard_at == Float::INFINITY
          raise FlowInvalidTransition, "Secret OIDC source claim mismatch"
        end

        verify_secret_oidc_ceremony!(ceremony, authorization_transaction, now)
        return self if sign_in_session_issuance_pending? || sign_in_session_limit_pending?
        raise FlowInvalidTransition, "Secret OIDC handoff is not ready" unless sign_in_dashboard_pending?

        update!(
          status_id: ClientSignInFlowStatus::SESSION_ISSUANCE_PENDING,
          state: "SESSION_ISSUANCE_PENDING", step: "session_issuance",
        )
      end
    end
    self
  end

  # Expiration is terminal housekeeping, not an authentication transition.
  # Contend with canonical issuance on the same Ticket row and never change a
  # completed login or extend the original admission deadline.
  def expire_sign_in!
    with_lock do
      now = self.class.database_now
      unless expired?(now) && session_issued_at.nil? && token_id.nil? &&
          self.class::TRANSITIONS.fetch(status_id).include?(ClientSignInFlowStatus::FAILED)
        raise FlowInvalidTransition, "only an expired unissued sign-in can terminate"
      end

      update!(status_id: ClientSignInFlowStatus::FAILED, state: "FAILED", step: "failed")
    end
  end

  private

  def verify_secret_oidc_transaction!(authorization_transaction, now)
    unless authorization_transaction.secret_sign_in_flow_id == id &&
        authorization_transaction.authenticated? && authorization_transaction.auth_method == "passcode" &&
        authorization_transaction.actor_ref == principal.public_id &&
        !authorization_transaction.expired?(now: now) &&
        !authorization_transaction.login_challenge_expired?(now: now)
      raise FlowInvalidTransition, "Secret OIDC authorization transaction mismatch"
    end
  end

  def verify_secret_oidc_ceremony!(ceremony, authorization_transaction, now)
    unless ceremony&.completed? && ceremony.admitted? && ceremony.revoked_at.nil? &&
        ceremony.cancelled_at.nil? && ceremony.expires_at > now &&
        ceremony.admission_purpose == "authentication_handoff" &&
        ceremony.authorization_transaction_ref == authorization_transaction.transaction_id &&
        ceremony.authentication_method == "secret"
      raise FlowInvalidTransition, "Secret OIDC completed handoff mismatch"
    end
  end
end
