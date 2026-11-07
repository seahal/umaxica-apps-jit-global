# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_sign_up_flows
# Database name: op_base_app
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
class ClientSignUpFlow < OpBaseAppRecord
  include SignFlow
  include FlowSignUp
  include SignUpFlowTicket

  cycle_status_column :status_id

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

  # A sign-up flow starts before a root token exists and keeps its own lifecycle if no token is issued.
  belongs_to :token, class_name: "ClientToken", optional: true
  belongs_to :auth_admission_binding, class_name: "ClientAuthAdmissionBinding", optional: false
  attr_readonly :auth_admission_binding_id
  belongs_to :principal, class_name: "Client", optional: true
  belongs_to :status, class_name: "ClientSignUpFlowStatus"
  belongs_to :cleanup_status, class_name: "ClientSignUpFlowCleanupStatus", optional: false

  validates :status_id, inclusion: { in: ->(record) { record.class::STATUS_IDS } }
  validates :step, presence: true, inclusion: { in: STEPS }
  validates :state, presence: true
  validate :legacy_state_matches_status
  validate :step_matches_status
  validate :completed_status_has_completed_at
  validate :sign_up_admission_is_redeemed, on: :create

  validates :social_provider, inclusion: { in: SOCIAL_ENTRY_METHODS }, allow_nil: true
  validates :result_digest, length: { maximum: 64 }

  before_validation :assign_default_status_id
  before_validation :sync_legacy_state_from_status

  def self.cleanup_status_class
    ClientSignUpFlowCleanupStatus
  end

  public

  # Source lock precedes OP SID/parent/Flow locks, including expiry and cleanup decisions.
  # Completion is reconciled before generic expiry evaluation, never from current actor status.
  def with_cycle_lock
    return super if @registration_lock_held || principal_id.blank?

    AppZenithRecord.connected_to(role: :writing) do
      Client.transaction do
        owner = Client.lock.find(principal_id)
        OpBaseAppRecord.connected_to(role: :writing) do
          self.class.transaction do
            lock_registration_parent!
            @registration_lock_held = true
            begin
              super do
                if principal_id != owner.id
                  raise ClientRegistrationCompletion::Conflict, "Registration actor changed while locking"
                end

                receipt = registration_completion
                complete_from_registration!(receipt) if receipt
                yield
              end
            ensure
              @registration_lock_held = false
            end
          end
        end
      end
    end
  end

  def registration_completion
    receipt = ClientRegistrationCompletion.find_by(sign_up_flow_ref: public_id)
    if !receipt && principal_id && ClientRegistrationCompletion.exists?(client_id: principal_id)
      raise ClientRegistrationCompletion::Conflict, "Client completion belongs to another signup flow"
    end

    receipt&.verify_flow!(self)
  end

  def lock_registration_parent!
    binding = association(:auth_admission_binding).scope.take!
    ceremony = binding.association(:admitted_auth_ceremony_session).scope.lock.take!
    parent = binding.association(:authorization_transaction).scope.lock.take!
    binding.lock!
    unless binding.entry_intent == "sign_up" && binding.purpose == "authentication_handoff" &&
        ceremony.authorization_transaction_ref == parent.transaction_id
      raise ArgumentError, "Registration parent ownership mismatch"
    end

    @registration_ceremony, @registration_parent, @registration_binding = ceremony, parent, binding
  end

  def require_registration_authority!
    now = self.class.database_now
    unless @registration_ceremony && @registration_parent && @registration_binding &&
        @registration_ceremony.active?(now: now) && @registration_ceremony.admitted? &&
        @registration_parent.pending? && @registration_parent.expires_at > now &&
        @registration_binding.redeemed? && !@registration_binding.retired? &&
        @registration_binding.curfew_at > now && expires_at > now && !lapsed?(now)
      raise FlowInvalidTransition, "Registration parent is no longer authorized"
    end
  end

  private

  def complete_from_registration!(receipt)
    receipt.verify_flow!(self)
    return self if sign_up_completed?
    unless status_id == ClientSignUpFlowStatus::FINALIZING
      raise ClientRegistrationCompletion::Conflict, "Committed registration has a conflicting flow state"
    end

    @completing_registration = true
    begin
      complete_sign_up!
    ensure
      @completing_registration = false
    end
    self
  end

  private

  def cycle_expires_at_lapsed?(now)
    return false if @completing_registration

    super
  end
end
