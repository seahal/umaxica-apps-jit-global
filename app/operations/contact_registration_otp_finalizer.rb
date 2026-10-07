# frozen_string_literal: true

class ContactRegistrationOtpFinalizer
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

  def initialize(actor:, actor_context:, token:, contact:, transaction:, channel:, browser_nonce:, requirement:,
                 bootstrap_transaction: nil)
    @actor, @actor_context, @token, @contact = actor, actor_context, token, contact
    @transaction, @channel, @browser_nonce, @requirement = transaction, channel, browser_nonce, requirement
    @bootstrap_transaction = bootstrap_transaction
    @surface, @policy_model, @audit_model =
      case [actor, token, contact, transaction, channel]
      in [Client, ClientToken, ClientEmail, ClientEmailCeremonyTransaction, :email]
        ["app", ClientEmailPolicy, ClientContactAuditOutbox]
      in [Client, ClientToken, ClientTelephone, ClientTelephoneCeremonyTransaction, :telephone]
        ["app", ClientTelephonePolicy, ClientContactAuditOutbox]
      in [Visitor, VisitorToken, VisitorEmail, VisitorEmailCeremonyTransaction, :email]
        ["com", VisitorEmailPolicy, VisitorContactAuditOutbox]
      in [Visitor, VisitorToken, VisitorTelephone, VisitorTelephoneCeremonyTransaction, :telephone]
        ["com", VisitorTelephonePolicy, VisitorContactAuditOutbox]
      else raise ArgumentError, "unsupported registration finalization binding"
      end
  end

  def call!
    return :unavailable unless browser_nonce.is_a?(String) && browser_nonce.match?(/\A[A-Za-z0-9_-]{43}\z/)

    transaction.class.connection_owner.connected_to(role: :writing) do
      transaction.class.transaction do
        committed = with_original_source_locks { finalize_source! }
        return :unavailable unless committed

        if bootstrap_transaction && !bootstrap_transaction.consumed?
          bootstrap_transaction.consume_email_registration!(registered_credential_ref: contact.public_id)
        end
        transaction.consume_registration_result! unless transaction.consumed?
        :finalized
      end
    end
  end

  def bootstrap_receipt_pending?
    return false unless bootstrap_transaction &&
      browser_nonce.is_a?(String) && browser_nonce.match?(/\A[A-Za-z0-9_-]{43}\z/)

    transaction.class.connection_owner.connected_to(role: :writing) do
      transaction.class.transaction do
        with_original_source_locks do
          now = transaction.class.database_now
          original_authority?(now, contact.class.database_now) && current_policy_matches? &&
            contact.binding_effective? && committed_provenance? &&
            transaction.status == "pending" && transaction.consumed_at.nil? && bootstrap_authorized?(now)
        end
      end
    end
  end

  private

  attr_reader :actor, :actor_context, :token, :contact, :transaction, :channel, :browser_nonce,
              :requirement, :surface, :policy_model, :audit_model, :bootstrap_transaction,
              :bootstrap_session, :bootstrap_binding

  def with_original_source_locks
    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        token.device_session.with_lock do
          token.with_lock do
            next false unless lock_bootstrap_authority!

            transaction.lock!
            contact.with_lock { yield }
          end
        end
      end
    end
  end

  def lock_bootstrap_authority!
    return true unless bootstrap_transaction

    unless channel == :email &&
        ((surface == "app" && bootstrap_transaction.is_a?(ClientStepUpCeremonyTransaction)) ||
         (surface == "com" && bootstrap_transaction.is_a?(VisitorStepUpCeremonyTransaction)))
      raise ArgumentError, "unsupported registration bootstrap binding"
    end

    @bootstrap_session =
      if surface == "app"
        ClientStepUpSession.lock.find_by(user_token_id: token.id)
      else
        VisitorStepUpSession.lock.find_by(visitor_token_id: token.id)
      end
    return false unless bootstrap_session &&
      bootstrap_session.step_up_ceremony_transaction_ref == bootstrap_transaction.transaction_id

    bootstrap_transaction.lock!
    bindings =
      if surface == "app"
        ClientAuthAdmissionBinding.where(step_up_ceremony_transaction_id: bootstrap_transaction.id).lock.to_a
      else
        VisitorAuthAdmissionBinding.where(step_up_ceremony_transaction_id: bootstrap_transaction.id).lock.to_a
      end
    return false unless bindings.one?

    @bootstrap_binding = bindings.first
    true
  end

  def bootstrap_authorized?(now, receipt: false)
    parent = bootstrap_transaction
    return false unless parent && bootstrap_session && bootstrap_binding

    bootstrap_parent_status_matches?(receipt:) && bootstrap_parent_binding_matches?(now) &&
      bootstrap_return_target_matches? &&
      bootstrap_browser_binding_matches?(now)
  end

  def bootstrap_parent_status_matches?(receipt:)
    bootstrap_transaction.status == "pending" ||
      (receipt && bootstrap_transaction.consumed? &&
        bootstrap_transaction.verified_credential_ref == contact.public_id &&
        bootstrap_transaction[:method] == "email_otp")
  end

  def bootstrap_parent_binding_matches?(now)
    parent = bootstrap_transaction
    parent.purpose == "bootstrap" && parent.allowed_methods_array == ["email_otp"] &&
      parent.surface == surface && parent.actor_ref == actor.public_id && parent.session_ref == token.public_id &&
      parent.token_binding == token.public_id && parent.require_session_binding &&
      parent.audience == "step_up:#{surface}" && parent.expires_at > now &&
      !parent.step_up_required && !parent.phishing_resistant_required && !parent.user_verification_required &&
      !parent.full_reauthentication_required
  end

  def bootstrap_browser_binding_matches?(now)
    bootstrap_session.status == "PENDING" &&
      bootstrap_session.discard_at > now && bootstrap_binding.base_token_id == token.id &&
      bootstrap_binding.purpose == "bootstrap_handoff" && bootstrap_binding.retired_at.nil? &&
      bootstrap_binding.base_browser_digest == AuthAdmissionBinding.browser_digest(
        surface:, entry_ref: bootstrap_binding.entry_ref, nonce: browser_nonce,
      )
  end

  def bootstrap_return_target_matches?
    catalog = (surface == "app") ? StepUpScopeCatalog::APP : StepUpScopeCatalog::COM
    scope = bootstrap_transaction.required_scope
    target = bootstrap_transaction.return_to
    target.is_a?(String) && catalog.key?(scope) && catalog.fetch(scope).match?(target) &&
      bootstrap_session.scope == scope && bootstrap_session.return_to == target
  end

  def finalize_source!
    ticket_now = transaction.class.database_now
    source_now = contact.class.database_now
    return false unless original_authority?(ticket_now, source_now) && current_policy_matches?

    if contact.binding_effective?
      return committed_provenance? && (!bootstrap_transaction || bootstrap_authorized?(ticket_now, receipt: true))
    end
    return false if transaction.consumed? || contact.binding_finalized_at || contact.binding_released?

    previous = previous_bindings.lock.to_a
    return false unless bootstrap_transaction ? bootstrap_authorized?(ticket_now) : current_credential?

    decision_time = transaction.class.database_now
    return false unless original_authority?(decision_time, contact.class.database_now) && current_policy_matches? &&
      registration_authorized?(decision_time)

    previous.each do |binding|
      binding.release_binding!
      binding.clear_otp
      record_audit!(binding, "released")
    end
    contact.finalize_registration_binding!
    record_audit!(contact, "finalized")
    true
  end

  def registration_authorized?(now)
    if bootstrap_transaction
      bootstrap_authorized?(now)
    else
      StepUpResolver.call(token:, requirement:, now:).satisfied?
    end
  end

  def original_authority?(ticket_now, source_now)
    proof = contact.credential_registration_otp_context
    return false unless proof&.fetch("verified_at") &&
      Time.iso8601(proof.fetch("result_expires_at")) > source_now

    actor.login_allowed? && actor.accessible?(source_now) && contact.accessible?(source_now) &&
      source_owner_matches? && context_matches?(proof) &&
      token.currently_usable?(ticket_now) && token.device_session.usable? &&
      token.device_session.current_refresh_token_id == token.id &&
      transaction.expires_at > ticket_now && transaction.surface == surface &&
      transaction.operation == "registration" && transaction.actor_ref == actor.public_id &&
      transaction.session_ref == token.public_id && ticket_candidate_matches? && actor_context_matches?
  end

  def context_matches?(proof)
    proof.fetch("version") == 1 && proof.fetch("surface") == surface &&
      proof.fetch("purpose") == "credential_registration" && proof.fetch("flow_ref") == transaction.transaction_id &&
      proof.fetch("session_ref") == token.public_id && proof.fetch("owner_ref") == actor.public_id &&
      proof.fetch("contact_ref") == contact.public_id && proof.fetch("destination_digest") == destination_digest &&
      proof.fetch("browser_digest") == AuthAdmissionBinding.browser_digest(
        surface:, entry_ref: transaction.transaction_id, nonce: browser_nonce,
      )
  end

  def source_owner_matches?
    case actor
    when Client then token.user_id == actor.id && contact.user_id == actor.id
    when Visitor then token.visitor_id == actor.id && contact.visitor_id == actor.id
    end
  end

  def actor_context_matches?
    actor_context.is_a?(ActorValuesContext) && actor_context.subject == actor &&
      actor_context.tld.to_s == surface && actor_context.surface == :base &&
      actor_context.actor_type == ((surface == "app") ? :client : :visitor)
  end

  def ticket_candidate_matches?
    if channel == :email
      transaction.email_candidate_ref == contact.public_id && transaction.normalized_email_digest == destination_digest
    else
      transaction.telephone_candidate_ref == contact.public_id &&
        transaction.normalized_number_digest == destination_digest
    end
  end

  def destination_digest = (channel == :email) ? contact.address_digest : contact.number_digest

  def current_policy_matches?
    requirement.is_a?(StepUpRequirement) &&
      requirement.to_h == policy_model.new(contact, user: actor).credential_registration_requirement(token:).to_h
  end

  def current_credential?
    credentials =
      case [actor, token.last_step_up_method]
      in [Client, "passkey"] then actor.client_passkeys.active
      in [Visitor, "passkey"] then actor.visitor_passkeys.active
      in [Client, "email_otp"]
        actor.client_emails.effective_binding.where(user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES)
      in [Visitor, "email_otp"]
        actor.visitor_emails.effective_binding.where(visitor_email_status_id: AuthMethodGuard::VISITOR_VERIFIED_EMAIL_STATUSES)
      in [Client, "totp"]
        actor.client_totp_credentials.where(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
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
    when Client
      ((channel == :email) ? actor.client_emails : actor.client_telephones).effective_binding.where.not(id: contact.id)
    when Visitor
      ((channel == :email) ? actor.visitor_emails : actor.visitor_telephones)
        .effective_binding.where.not(id: contact.id)
    end
  end

  def committed_provenance?
    !contact.binding_released? && audit_model.exists?(
      operation_ref: transaction.transaction_id, owner_ref: actor.public_id, actor_ref: actor.public_id,
      contact_ref: contact.public_id, contact_kind: channel.to_s, event_name: "finalized",
    )
  end

  def record_audit!(subject, event_name)
    ContactBindingAuditRecorder.call!(
      actor_context:, actor:, contact: subject, operation_ref: transaction.transaction_id, event_name:,
    )
  end
end
