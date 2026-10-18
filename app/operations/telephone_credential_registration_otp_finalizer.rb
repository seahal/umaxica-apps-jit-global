# frozen_string_literal: true

class TelephoneCredentialRegistrationOtpFinalizer
  class << self
    public

    def call!(**arguments)
      new(**arguments).call!
    end
  end

  public

  def initialize(actor:, actor_context:, token:, telephone:, transaction:, browser_nonce:, requirement:, code:)
    @actor, @actor_context, @token, @telephone = actor, actor_context, token, telephone
    @transaction, @browser_nonce, @requirement, @code = transaction, browser_nonce, requirement, code
    @surface, @policy_model, @audit_model =
      case [actor, token, telephone, transaction]
      in [Client, ClientToken, ClientTelephone, ClientTelephoneCeremonyTransaction]
        ["app", ClientTelephonePolicy, ClientContactAuditOutbox]
      in [Visitor, VisitorToken, VisitorTelephone, VisitorTelephoneCeremonyTransaction]
        ["com", VisitorTelephonePolicy, VisitorContactAuditOutbox]
      else raise ArgumentError, "unsupported Telephone registration finalization realm"
      end
  end

  def call!
    return :unavailable unless browser_nonce.is_a?(String) && browser_nonce.encoding.ascii_compatible? &&
      browser_nonce.valid_encoding? && browser_nonce.match?(/\A[A-Za-z0-9_-]{43}\z/)

    transaction.class.connection_owner.connected_to(role: :writing) do
      transaction.class.transaction do
        committed = with_original_locks { finalize_source! }
        next :unavailable unless committed

        transaction.consume_registration_result! unless transaction.consumed?
        :finalized
      end
    end
  end

  private

  attr_reader :actor, :actor_context, :token, :telephone, :transaction, :browser_nonce, :requirement, :code,
              :surface, :policy_model, :audit_model

  def with_original_locks
    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        token_device_session.with_lock do
          token.with_lock do
            telephone.with_lock do
              transaction.lock!
              yield
            end
          end
        end
      end
    end
  end

  def finalize_source!
    now = transaction.class.database_now
    return false unless original_authority?(now) && current_policy_matches?
    return committed_provenance? if telephone.binding_effective?
    return false if transaction.consumed? || telephone.binding_finalized_at || telephone.binding_released?

    previous = previous_bindings.lock.to_a
    return false unless current_credential?

    now = transaction.class.database_now
    return false unless original_authority?(now) && current_policy_matches? &&
      StepUpResolver.call(token: token, requirement: requirement, now: now).satisfied?

    previous.each do |binding|
      binding.release_binding!
      record_audit!(binding, "released")
    end
    telephone.finalize_registration_binding!(transaction: transaction, code: code, session_ref: session_ref)
    record_audit!(telephone, "finalized")
    true
  end

  def original_authority?(now)
    source_now = telephone.class.database_now
    return false unless actor.login_allowed? && actor.accessible?(source_now) && telephone.accessible?(source_now) &&
      source_owned? && actor_context_matches? && root_current?(now)
    return false unless transaction.surface == surface &&
      transaction.normalized_number_digest == telephone.number_digest && transaction.session_ref == session_ref

    transaction.telephone_registration_otp_evidence?(
      code: code, actor_ref: actor.public_id, session_ref: session_ref, candidate_ref: telephone.public_id,
    )
  end

  def session_ref
    CredentialRegistrationOtpSessionValue.for(
      surface: surface, channel: :telephone, transaction_ref: transaction.transaction_id,
      root_ref: token.public_id, browser_nonce: browser_nonce,
    ).dump
  end

  def source_owned?
    case actor
    when Client
      token.user_id == actor.id && token_device_session.user_id == actor.id && telephone.user_id == actor.id
    when Visitor
      token.visitor_id == actor.id && token_device_session.visitor_id == actor.id && telephone.visitor_id == actor.id
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
      requirement.to_h == policy_model.new(
        telephone,
        user: actor,
      ).credential_registration_requirement(token: token).to_h
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
    when Client then ClientTelephone.where(user_id: actor.id).effective_binding.where.not(id: telephone.id)
    when Visitor then VisitorTelephone.where(visitor_id: actor.id).effective_binding.where.not(id: telephone.id)
    end
  end

  def committed_provenance?
    !telephone.binding_released? && audit_model.exists?(
      operation_ref: transaction.transaction_id, owner_ref: actor.public_id, actor_ref: actor.public_id,
      contact_ref: telephone.public_id, contact_kind: "telephone", event_name: "finalized",
    )
  end

  def record_audit!(subject, event_name)
    ContactBindingAuditRecorder.call!(
      actor_context: actor_context, actor: actor, contact: subject,
      operation_ref: transaction.transaction_id, event_name: event_name,
    )
  end
end
