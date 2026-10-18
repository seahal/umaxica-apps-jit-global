# frozen_string_literal: true

class EmailCredentialRegistrationOtpFinalizer
  class << self
    public

    def call!(**arguments)
      new(**arguments).call!
    end

    def bootstrap_receipt_pending?(**arguments)
      new(**arguments).bootstrap_receipt_pending?
    end
  end

  public

  def initialize(actor:, actor_context:, token:, email:, transaction:, browser_nonce:, requirement:, code:,
                 bootstrap_transaction: nil)
    @actor, @actor_context, @token, @email = actor, actor_context, token, email
    @transaction, @browser_nonce, @requirement, @code = transaction, browser_nonce, requirement, code
    @bootstrap_transaction = bootstrap_transaction
    @surface, @policy_model, @audit_model =
      case [actor, token, email, transaction]
      in [Client, ClientToken, ClientEmail, ClientEmailCeremonyTransaction]
        ["app", ClientEmailPolicy, ClientContactAuditOutbox]
      in [Visitor, VisitorToken, VisitorEmail, VisitorEmailCeremonyTransaction]
        ["com", VisitorEmailPolicy, VisitorContactAuditOutbox]
      else raise ArgumentError, "unsupported Email registration finalization realm"
      end
  end

  def call!
    return :unavailable unless browser_nonce.is_a?(String) && browser_nonce.encoding.ascii_compatible? &&
      browser_nonce.valid_encoding? && browser_nonce.match?(/\A[A-Za-z0-9_-]{43}\z/)

    transaction.class.connection_owner.connected_to(role: :writing) do
      transaction.class.transaction do
        committed = with_original_locks { finalize_source! }
        return :unavailable unless committed

        if bootstrap_transaction && !bootstrap_transaction.consumed?
          bootstrap_transaction.consume_email_registration!(registered_credential_ref: email.public_id)
        end
        transaction.consume_registration_result! unless transaction.consumed?
        :finalized
      end
    end
  end

  def bootstrap_receipt_pending?
    return false unless bootstrap_transaction && valid_browser_nonce?

    transaction.class.connection_owner.connected_to(role: :writing) do
      transaction.class.transaction do
        with_original_locks do
          now = transaction.class.database_now
          original_binding?(now) && current_policy_matches? && bounded_pending_receipt?(now) &&
            email.binding_effective? && committed_provenance? &&
            transaction.status == "pending" && transaction.consumed_at.nil?
        end
      end
    end
  end

  private

  attr_reader :actor, :actor_context, :token, :email, :transaction, :browser_nonce, :requirement, :code,
              :surface, :policy_model, :audit_model, :bootstrap_transaction

  def with_original_locks
    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        token_device_session.with_lock do
          token.with_lock do
            email.with_lock do
              if bootstrap_transaction
                next false unless transaction.bootstrap_ceremony_transaction_ref == bootstrap_transaction.transaction_id

                EmailCredentialRegistrationBootstrapGuard.call(
                  actor: actor, token: token, bootstrap_transaction: bootstrap_transaction,
                  browser_nonce: browser_nonce, credential_ref: email.public_id, receipt: email.binding_effective?,
                ) do
                  transaction.lock!
                  yield
                end
              else
                transaction.lock!
                next false if transaction.bootstrap_ceremony_transaction_ref

                yield
              end
            end
          end
        end
      end
    end
  end

  def finalize_source!
    now = transaction.class.database_now
    return false unless original_authority?(now) && current_policy_matches?
    return committed_provenance? if email.binding_effective?
    return false if transaction.consumed? || email.binding_finalized_at || email.binding_released?

    previous = previous_bindings.lock.to_a
    return false unless bootstrap_transaction || current_credential?

    now = transaction.class.database_now
    return false unless original_authority?(now) && current_policy_matches? &&
      (bootstrap_transaction || StepUpResolver.call(token: token, requirement: requirement, now: now).satisfied?)

    previous.each do |binding|
      binding.release_binding!
      record_audit!(binding, "released")
    end
    email.finalize_registration_binding!(transaction: transaction, code: code, session_ref: transaction.session_ref)
    record_audit!(email, "finalized")
    true
  end

  def original_authority?(now)
    return false unless original_binding?(now)

    transaction.email_registration_otp_evidence?(
      code: code, actor_ref: actor.public_id, session_ref: transaction.session_ref, candidate_ref: email.public_id,
    )
  end

  def original_binding?(now)
    source_now = email.class.database_now
    return false unless actor.login_allowed? && actor.accessible?(source_now) && email.accessible?(source_now) &&
      source_owned? && actor_context_matches? && root_current?(now)

    expected = CredentialRegistrationOtpSessionValue.for(
      surface: surface, channel: :email, transaction_ref: transaction.transaction_id,
      root_ref: token.public_id, browser_nonce: browser_nonce,
    ).dump
    transaction.surface == surface && transaction.normalized_email_digest == email.address_digest &&
      transaction.actor_ref == actor.public_id && transaction.email_candidate_ref == email.public_id &&
      transaction.operation == "registration" && transaction.purpose == "credential_registration" &&
      transaction.session_ref == expected && original_bootstrap_matches?(now)
  end

  def bounded_pending_receipt?(now)
    transaction.status == "pending" && transaction.consumed_at.nil? && transaction.expires_at > now &&
      transaction.otp_cancelled_at.nil? && transaction.otp_consumed_at && transaction.otp_consumed_at <= now &&
      transaction.otp_result_expires_at && transaction.otp_result_expires_at > now &&
      transaction.otp_receipt_verifier.is_a?(String) && transaction.otp_receipt_verifier.match?(/\A[0-9a-f]{64}\z/)
  end

  def original_bootstrap_matches?(now)
    return false unless transaction.bootstrap_ceremony_transaction_ref == bootstrap_transaction&.transaction_id
    return true unless bootstrap_transaction

    bootstrap_transaction.expires_at > now &&
      (bootstrap_transaction.status == "pending" ||
       (email.binding_effective? && bootstrap_transaction.consumed? &&
        bootstrap_transaction.verified_credential_ref == email.public_id &&
        bootstrap_transaction[:method] == "email_otp"))
  end

  def valid_browser_nonce?
    browser_nonce.is_a?(String) && browser_nonce.encoding.ascii_compatible? &&
      browser_nonce.valid_encoding? && browser_nonce.match?(/\A[A-Za-z0-9_-]{43}\z/)
  end

  def source_owned?
    case actor
    when Client
      token.user_id == actor.id && token_device_session.user_id == actor.id && email.user_id == actor.id
    when Visitor
      token.visitor_id == actor.id && token_device_session.visitor_id == actor.id && email.visitor_id == actor.id
    end
  end

  def root_current?(now)
    token.active_status?(now) && token_device_session.usable? &&
      token_device_session.current_refresh_token_id == token.id
  end

  def token_device_session
    token.device_session_record!
  end

  def actor_context_matches?
    actor_context.is_a?(ActorValuesContext) && actor_context.subject == actor &&
      actor_context.tld.to_s == surface && actor_context.surface == :base &&
      actor_context.actor_type == ((surface == "app") ? :client : :visitor)
  end

  def current_policy_matches?
    requirement.is_a?(StepUpRequirement) &&
      requirement.to_h == policy_model.new(email, user: actor).credential_registration_requirement(token: token).to_h
  end

  def current_credential?
    credentials =
      case [actor, token.last_step_up_method]
      in [Client, "passkey"] then ClientPasskey.where(user_id: actor.id).active
      in [Visitor, "passkey"] then VisitorPasskey.where(visitor_id: actor.id).active
      in [Client, "email_otp"]
        ClientEmail.where(user_id: actor.id).effective_binding.where(
          user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES,
        )
      in [Visitor, "email_otp"]
        VisitorEmail.where(visitor_id: actor.id).effective_binding.where(
          visitor_email_status_id: AuthMethodGuard::VISITOR_VERIFIED_EMAIL_STATUSES,
        )
      in [Client, "totp"]
        ClientTotpCredential.where(
          user_id: actor.id, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
        )
      else return false
      end
    credential = credentials.lock.find_by(public_id: token.last_step_up_credential_ref)
    return false unless credential

    case credential
    when ClientTotpCredential then credential.usable?
    else credential.accessible?(credential.class.database_now)
    end
  end

  def previous_bindings
    case actor
    when Client then actor.client_emails.effective_binding.where.not(id: email.id)
    when Visitor then actor.visitor_emails.effective_binding.where.not(id: email.id)
    end
  end

  def committed_provenance?
    !email.binding_released? && audit_model.exists?(
      operation_ref: transaction.transaction_id, owner_ref: actor.public_id, actor_ref: actor.public_id,
      contact_ref: email.public_id, contact_kind: "email", event_name: "finalized",
    )
  end

  def record_audit!(subject, event_name)
    ContactBindingAuditRecorder.call!(
      actor_context: actor_context, actor: actor, contact: subject,
      operation_ref: transaction.transaction_id, event_name: event_name,
    )
  end
end
