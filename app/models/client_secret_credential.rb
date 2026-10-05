# frozen_string_literal: true

class ClientSecretCredential < AppZenithRecord
  include PublicId
  include Retainable

  MAX_PER_CLIENT = 20
  SECRET_FORMAT = /\A[1-9A-HJ-NP-Za-km-z]{32}\z/

  class InvalidTransition < StandardError; end

  has_secure_password algorithm: :argon2, validations: false

  belongs_to :client, inverse_of: :client_secret_credentials
  belongs_to :issuance, class_name: "ClientSecretIssuance"

  attr_readonly :public_id, :client_id, :issuance_id, :password_digest, :lookup_digest

  validates :name, presence: true, length: { maximum: 255 }
  validates :password_digest, presence: true, length: { maximum: 255 }
  validates :lookup_digest, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :password, format: { with: SECRET_FORMAT }, allow_nil: true
  validate :persisted_revocation_is_immutable, on: :update
  validate :revocation_has_source_audit, on: :update
  validate :terminal_issuance_cannot_confirm_candidate
  validate :confirmation_has_source_audit, on: :update
  validate :persisted_confirmation_is_immutable, on: :update

  scope :available_at, ->(at) {
    where.not(confirmed_at: nil).where(claimed_at: nil, claim_operation_id: nil, revoked_at: nil)
      .where("discard_at > ?", at)
  }

  public

  def commit_sign_in_claim!(actor_context:, flow:, ceremony:, at:)
    unless ClientSignInFlow.lease_connection.transaction_open? && flow.is_a?(ClientSignInFlow) &&
        ceremony.is_a?(ClientAuthCeremonySession)
      raise InvalidTransition, "Secret claim requires its locked durable Ticket transaction"
    end

    flow = ClientSignInFlow.lock.find_by!(id: flow.id, public_id: flow.public_id)
    ceremony = ClientAuthCeremonySession.lock.find(ceremony.id)
    verify_claim_binding!(actor_context, flow, ceremony, at)

    @authentication_fact_write = true
    self.claimed_at = at
    self.claim_operation_id = SecureRandom.uuid
    self.claim_sign_in_flow_ref = flow.public_id
    self.claim_ceremony_session_id = ceremony.id
    ClientSecretAuditOutbox.record!(
      actor_context: actor_context, client_ref: client.public_id, credential_ref: public_id,
      operation_ref: claim_operation_id, occurred_at: at, event_name: "secret.claimed",
    )
    save!
    self
  ensure
    @authentication_fact_write = false
  end

  def commit_sign_in_retirement!(actor_context:, at:, purge_at:, successful:, flow:, reason:)
    unless ClientSignInFlow.lease_connection.transaction_open? && flow.is_a?(ClientSignInFlow)
      raise InvalidTransition, "Secret retirement requires its locked durable Ticket transaction"
    end

    flow = ClientSignInFlow.lock.find_by!(id: flow.id, public_id: flow.public_id)
    unless self.class.lease_connection.transaction_open? && claimed_at && discard_at == Float::INFINITY &&
        at >= claimed_at && purge_at > at && actor_context.subject.id == client_id &&
        flow.public_id == claim_sign_in_flow_ref &&
        flow.principal_id == client_id
      raise InvalidTransition, "Secret retirement requires its terminal claim decision"
    end

    verify_retirement_outcome!(flow, successful, reason)

    @authentication_fact_write = true
    self.consumed_at = at if successful
    self.discard_at = at
    self.purge_eligible_at = purge_at
    events = successful ? %w(secret.consumed secret.discarded) : %w(secret.discarded)
    events.each do |event|
      ClientSecretAuditOutbox.record!(
        actor_context: actor_context, client_ref: client.public_id, credential_ref: public_id,
        operation_ref: claim_operation_id, occurred_at: at, event_name: event, reason: reason,
      )
    end
    save!
  ensure
    @authentication_fact_write = false
  end

  # confirmed_at needs a validated transition, so fixed Rails writer guards
  # protect ordinary assignments instead of excluding the column from every save.
  def write_attribute(name, value)
    verify_lifecycle_assignment!(name)
    super
  end

  def _write_attribute(name, value)
    verify_lifecycle_assignment!(name)
    super
  end

  def commit_storage_confirmation!(actor_context:, at:)
    unless (at.is_a?(Time) || at.is_a?(ActiveSupport::TimeWithZone)) &&
        self.class.lease_connection.transaction_open?
      raise InvalidTransition, "Secret confirmation requires its source transaction and timestamp"
    end

    unless storage_confirmation_context_matches?(actor_context) && confirmed_at.nil? &&
        claimed_at.nil? && claim_operation_id.nil? && revoked_at.nil? &&
        created_at <= at && accessible?(at) && issuance.reload.confirmed_at == at
      raise InvalidTransition, "Secret confirmation requires its owning storage declaration"
    end

    unless storage_confirmation_source_recorded?(at)
      raise InvalidTransition, "Secret confirmation requires its matching source audit"
    end

    @storage_confirmation_write = true
    self.confirmed_at = at
    save!
    self
  ensure
    @storage_confirmation_write = false
  end

  # Generic attribute assignment cannot write a persisted lifecycle fact.
  # The dedicated transition below validates and commits it with source audit.
  def revoked_at=(value)
    raise ActiveRecord::ReadonlyAttributeError, "revoked_at" if persisted?

    super
  end

  def commit_management_revocation!(actor_context:, at:, purge_at:)
    unless persisted? && actor_context.is_a?(ActorValuesContext) && actor_context.client? &&
        actor_context.tld == :app && actor_context.surface == :base &&
        actor_context.subject.is_a?(Client) && actor_context.subject.id == client_id
      raise InvalidTransition, "Secret revocation requires its owning Base app Client"
    end
    unless (at.is_a?(Time) || at.is_a?(ActiveSupport::TimeWithZone)) &&
        (purge_at.is_a?(Time) || purge_at.is_a?(ActiveSupport::TimeWithZone)) && purge_at > at
      raise InvalidTransition, "Secret revocation requires ordered finite timestamps"
    end

    AppZenithRecord.connected_to(role: :writing) do
      client.with_lock(requires_new: true) do
        with_lock do
          unless available_at?(at: at) && created_at <= at &&
              AuthMethodGuard.can_remove_secret_credential?(client, self)
            raise InvalidTransition, "Secret is unavailable for management revocation"
          end

          @management_revocation_write = true
          self[:revoked_at] = at
          self.discard_at = at
          self.purge_eligible_at = purge_at
          operation_ref = SecureRandom.uuid
          %w(secret.revoked secret.discarded).each do |event_name|
            ClientSecretAuditOutbox.record!(
              actor_context: actor_context.with(subject: client), client_ref: client.public_id,
              credential_ref: public_id, operation_ref: operation_ref, occurred_at: at,
              event_name: event_name, reason: "user_revocation",
            )
          end
          save!
        end
      end
    end
    self
  ensure
    @management_revocation_write = false
  end

  # Account termination owns this transition; it is not a management Step-Up.
  # Claimed credentials keep their continuation evidence until Ticket reconciliation.
  def commit_withdrawal_revocation!(at:, purge_at:)
    unless (at.is_a?(Time) || at.is_a?(ActiveSupport::TimeWithZone)) &&
        (purge_at.is_a?(Time) || purge_at.is_a?(ActiveSupport::TimeWithZone)) && purge_at > at
      raise InvalidTransition, "Secret withdrawal requires ordered retention timestamps"
    end

    AppZenithRecord.connected_to(role: :writing) do
      client.with_lock do
        raise InvalidTransition, "Secret withdrawal requires a terminated Client" unless client.terminated?

        with_lock do
          return self if revoked_at || discard_at != Float::INFINITY

          @management_revocation_write = true
          self[:revoked_at] = at
          events = ["secret.revoked"]
          unless claimed_at
            self.discard_at = at
            self.purge_eligible_at = purge_at
            events << "secret.discarded"
          end
          context = ActorValuesContext.empty.with(subject: client, actor_type: :client, tld: :app, surface: :base)
          operation_ref = SecureRandom.uuid
          events.each do |event_name|
            ClientSecretAuditOutbox.record!(
              actor_context: context, client_ref: client.public_id, credential_ref: public_id,
              operation_ref: operation_ref, occurred_at: at, event_name: event_name, reason: "withdrawal",
            )
          end
          save!
        end
      end
    end
    self
  ensure
    @management_revocation_write = false
  end

  def available_at?(at:)
    confirmed_at.present? && claimed_at.nil? && claim_operation_id.nil? &&
      revoked_at.nil? && accessible?(at)
  end

  def matches_secret?(raw)
    return false unless raw.is_a?(String) && raw.valid_encoding? && raw.ascii_only? && SECRET_FORMAT.match?(raw)
    return false unless lookup_digest.present? && password_digest.present?

    expected = SignSecretLookupDigest.digest(raw)
    return false unless ActiveSupport::SecurityUtils.secure_compare(expected, lookup_digest)

    authenticate(raw).present?
  end

  private

  def verify_claim_binding!(actor_context, flow, ceremony, at)
    unless self.class.lease_connection.transaction_open? && available_at?(at: at) &&
        flow.principal_id == client_id && flow.sign_in_primary_pending? &&
        !flow.expired?(ClientSignInFlow.database_now) &&
        ceremony.active?(now: ClientAuthCeremonySession.database_now) &&
        ceremony.admitted? && claim_ceremony_matches?(flow, ceremony) && !ceremony.authentication_evidence_recorded? &&
        actor_context.subject.id == client_id
      raise InvalidTransition, "Secret claim requires the owning admitted browser flow"
    end

  end

  def claim_ceremony_matches?(flow, ceremony)
    if ceremony.admission_purpose == "local_sign_in"
      return ceremony.local_sign_in_flow_ref == flow.public_id
    end
    return false unless ceremony.admission_purpose == "authentication_handoff"

    transaction = ClientOidcAuthorizationTransaction.lock.find_by(
      transaction_id: ceremony.authorization_transaction_ref, secret_sign_in_flow_id: flow.id,
    )
    now = ClientOidcAuthorizationTransaction.database_now
    transaction && transaction.status == "pending" &&
      !transaction.expired?(now: now) && !transaction.login_challenge_expired?(now: now)
  end

  def verify_retirement_outcome!(flow, successful, reason)
    receipt = ClientSecretSignInReceipt.find_by(operation_id: claim_operation_id)
    if successful
      unless receipt && receipt.credential_ref == public_id && receipt.sign_in_flow_id == flow.id &&
          flow.sign_in_completed? && receipt.root_token_ref == flow.token&.public_id &&
          receipt.committed_at == flow.session_issued_at
        raise InvalidTransition, "Secret consumption requires its durable successful receipt"
      end
    elsif receipt || !flow.sign_in_failed?
      raise InvalidTransition, "Unsuccessful Secret retirement requires its terminal flow"
    end
    verify_cancellation_outcome!(flow) if reason == "flow_canceled"
    valid_reason =
      successful ? reason == "login_committed" : %w(flow_failed flow_expired
                                                    flow_canceled).include?(reason)
    return if valid_reason && (reason != "flow_expired" || flow.expired?(ClientSignInFlow.database_now))

    raise InvalidTransition, "Secret retirement requires its verified terminal outcome reason"

  end

  def verify_cancellation_outcome!(flow)
    ceremony = ClientAuthCeremonySession.lock.find_by(id: claim_ceremony_session_id)
    return if ceremony && ceremony.local_sign_in_flow_ref == flow.public_id && ceremony.cancelled_at

    if ceremony&.admitted? && ceremony.admission_purpose == "authentication_handoff"
      transaction = ClientOidcAuthorizationTransaction.find_by(
        secret_sign_in_flow_id: flow.id, transaction_id: ceremony.authorization_transaction_ref,
      )
      return if transaction && transaction.base_finalized_at.nil? && transaction.browser_session_ref.nil? &&
        ClientSessionLimitResolutionTransaction.where(
          oidc_authorization_transaction_id: transaction.id,
          status: ClientSessionLimitResolutionTransaction::STATUS_CANCELLED,
        ).where.not(cancelled_at: nil).exists?
    end

    raise InvalidTransition, "Secret cancellation requires its durable canceled ceremony"

  end

  def storage_confirmation_context_matches?(context)
    persisted? && context.is_a?(ActorValuesContext) && context.client? &&
      context.tld == :app &&
      (context.surface == :base || (context.surface == :sign && issuance.sign_up_flow_ref.present?)) &&
      context.subject.is_a?(Client) &&
      context.subject.id == client_id
  end

  def verify_lifecycle_assignment!(name)
    return unless persisted?

    attribute = name.to_s
    if %w(claimed_at claim_operation_id claim_sign_in_flow_ref claim_ceremony_session_id
          consumed_at).include?(attribute) &&
        !@authentication_fact_write
      raise ActiveRecord::ReadonlyAttributeError, attribute
    end
    if attribute == "confirmed_at" && !@storage_confirmation_write
      raise ActiveRecord::ReadonlyAttributeError, "confirmed_at"
    end
    if attribute == "discard_at" && discard_at_in_database != Float::INFINITY
      raise ActiveRecord::ReadonlyAttributeError, "discard_at"
    end
    return unless attribute == "revoked_at" && !@management_revocation_write

    raise ActiveRecord::ReadonlyAttributeError, "revoked_at"
  end

  # Rails uses this hook for update_columns and touch; those APIs never perform
  # a source-audited, validated lifecycle transition.
  def verify_readonly_attribute(name)
    if %w(confirmed_at revoked_at claimed_at claim_operation_id claim_sign_in_flow_ref claim_ceremony_session_id
          consumed_at).include?(name.to_s)
      raise ActiveRecord::ReadonlyAttributeError, name.to_s
    end
    # A finite discard timestamp is an irreversible credential fact. Retention
    # updates and name changes cannot turn it back into an available Secret.
    if name.to_s == "discard_at" && discard_at_in_database != Float::INFINITY
      raise ActiveRecord::ReadonlyAttributeError, "discard_at"
    end

    super
  end

  def persisted_confirmation_is_immutable
    return unless confirmed_at_in_database && will_save_change_to_confirmed_at?

    errors.add(:confirmed_at, "cannot change a terminal storage declaration fact")
  end

  def confirmation_has_source_audit
    return unless confirmed_at && confirmed_at_in_database.nil? && will_save_change_to_confirmed_at?
    return if issuance.reload.confirmed_at == confirmed_at && storage_confirmation_source_recorded?(confirmed_at)

    errors.add(:confirmed_at, "requires its matching source audit and storage declaration")
  end

  def storage_confirmation_source_recorded?(at)
    created = ClientSecretAuditOutbox.exists?(
      client_ref: client.public_id, credential_ref: public_id, operation_ref: issuance.origin_operation_id,
      event_name: "secret.created", occurred_at: at,
      actor_type: "Client", actor_id: client_id, actor_public_ref: client.public_id,
    )
    created && ClientSecretAuditOutbox.exists?(
      client_ref: client.public_id, credential_ref: nil, operation_ref: issuance.origin_operation_id,
      event_name: "secret.storage_declared", occurred_at: at, item_count: issuance.planned_count,
      actor_type: "Client", actor_id: client_id, actor_public_ref: client.public_id,
    )
  end

  def terminal_issuance_cannot_confirm_candidate
    return unless confirmed_at && issuance && (issuance.canceled_at || issuance.planned_count.zero?)

    errors.add(:issuance, "canceled or omitted issuance cannot confirm a candidate")
  end

  def persisted_revocation_is_immutable
    return unless revoked_at_in_database && will_save_change_to_revoked_at?

    errors.add(:revoked_at, "cannot change a terminal revocation fact")
  end

  # Source events are a persistence prerequisite, not session authorization.
  # Only the management operation verifies the current browser and Step-Up.
  def revocation_has_source_audit
    return unless revoked_at && revoked_at_in_database.nil? && will_save_change_to_revoked_at?

    events = ClientSecretAuditOutbox.where(
      credential_ref: public_id, client_ref: client.public_id, actor_type: "Client", actor_id: client_id,
      actor_public_ref: client.public_id, occurred_at: revoked_at, reason: %w(user_revocation withdrawal),
      event_name: %w(secret.revoked secret.discarded),
    )
    return if events.group(:operation_ref).having("COUNT(DISTINCT event_name) = 2").exists?
    return if claimed_at && client.terminated? && events.exists?(event_name: "secret.revoked", reason: "withdrawal")

    errors.add(:revoked_at, "requires its matching source audit transaction")
  end
end
