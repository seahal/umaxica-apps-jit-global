# frozen_string_literal: true

# Caller supplies an authorized, owner-scoped record. The owner lock serializes inventory
# decisions with registration and Base finalization. Passkeys are current-state credentials:
# successful user removal physically deletes the row and records the stable audit fact in the
# principal-side outbox before the delete commits.
class IdentityCredentialRemovalCommitter
  class << self
    public

    def call!(actor:, credential:, current_session:, actor_context: nil, request: nil)
      new(
        actor: actor, credential: credential, current_session: current_session,
        actor_context: actor_context, request: request,
      ).call!
    end
  end

  public

  def initialize(actor:, credential:, current_session:, actor_context: nil, request: nil)
    @actor = actor
    @credential = credential
    @current_session = current_session
    @actor_context = actor_context
    @request = request
  end

  def call!
    validate_binding!
    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        return false unless actor.login_allowed?

        invalidated =
          current_session.class.connection_class_for_self.connected_to(role: :writing) do
            device = current_session.device_session_record!
            device.with_lock do
              return false unless authorized_device?(device)

              current_session.with_lock do
                credential.lock!
                validate_binding!
                validate_session!(device)
                if current_session.is_a?(OperatorToken) && current_session.standby_authentication_context?
                  raise ArgumentError, "credential removal requires a Normal session"
                end
                return false if terminal? || (contact? && !credential.binding_effective?) || !removable?
                return false unless passkey_management_authorized? && client_credential_management_authorized?

                # Ticket invalidation precedes principal mutation. A separate-DB failure can
                # remove freshness while retaining the credential, but cannot preserve stale authority.
                CredentialSecurityTransition.call(
                  actor: actor, current_session: current_session, reason: :mfa_level_changed,
                  affected_surface: surface, revoke_other_sessions: false, request: request,
                )
                true
              end
            end
          end
        return false unless invalidated

        remove_credential!
        record_contact_release_intent!
        true
      end
    end
  end

  private

  attr_reader :actor, :credential, :current_session, :actor_context, :request

  def validate_session!(device)
    now =
      case current_session
      when ClientToken then ClientToken.database_now
      when OperatorToken then OperatorToken.database_now
      else raise ArgumentError, "unsupported credential removal session"
      end
    return if current_session.device_session_id == device.id && current_session.active_status?(now)

    raise ArgumentError, "credential removal session is unavailable"
  end

  def authorized_device?(device)
    owner_matches =
      case [actor, device]
      in [Client, ClientDeviceSession] then device.user_id == actor.id
      in [Operator, OperatorDeviceSession] then device.staff_id == actor.id
      else false
      end
    owner_matches && device.usable? && device.current_refresh_token_id == current_session.id
  end

  def validate_binding!
    owner_matches =
      case [actor, credential, current_session]
      in [Client, ClientPasskey | ClientTotpCredential | ClientEmail | ClientTelephone, ClientToken]
        credential.user_id == actor.id && current_session.user_id == actor.id
      in [Operator, OperatorPasskey, OperatorToken]
        credential.staff_id == actor.id && current_session.staff_id == actor.id
      else false
      end
    raise ArgumentError, "credential removal binding mismatch" unless owner_matches
    unless actor.persisted? && credential.persisted? && current_session.persisted?
      raise ArgumentError, "credential removal requires persisted records"
    end

    validate_contact_context!
  end

  def contact?
    credential.is_a?(ClientEmail) || credential.is_a?(ClientTelephone)
  end

  def passkey_management_authorized?
    policy =
      case credential
      when ClientPasskey then ClientPasskeyPolicy.new(credential, user: actor)
      when OperatorPasskey then OperatorPasskeyPolicy.new(credential, user: actor)
      when ClientTotpCredential, ClientEmail, ClientTelephone then return true
      else raise ArgumentError, "unsupported removal credential"
      end
    evidence = policy.management_credential(token: current_session)
    return false unless evidence

    evidence.lock!
    policy.apply(:destroy?) && policy.management_authorized?(
      token: current_session, now: current_session.class.database_now,
    )
  end

  def client_credential_management_authorized?
    scope =
      case credential
      when ClientTotpCredential then "settings_totp"
      when ClientEmail then "settings_email"
      when ClientTelephone then "settings_telephone"
      else return true
      end
    requirement = StepUpRequirement.new(
      scope: scope, step_up_required: true, allowed_methods: %i(passkey totp email_otp),
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, purpose: "step_up", audience: "step_up:app",
      session_binding: current_session.public_id, token_binding: current_session.public_id,
      require_session_binding: true, ttl: StepUpRequirement::DEFAULT_TTL,
      actor_ref: actor.public_id, resource_ref: credential.public_id, tenant_ref: nil,
    )
    StepUpResolver.call(token: current_session, requirement: requirement, now: ClientToken.database_now).satisfied?
  end

  def validate_contact_context!
    return unless contact?

    expected_role = :client
    unless actor_context.is_a?(ActorValuesContext) && actor_context.subject == actor &&
        actor_context.actor_type == expected_role && actor_context.tld.to_s == surface
      raise ArgumentError, "Contact removal requires its authenticated Actor context"
    end
    raise ArgumentError, "Contact owner is unavailable" unless actor.active?
  end

  def record_contact_release_intent!
    return unless contact?

    ContactBindingAuditRecorder.call!(
      actor_context: actor_context, actor: actor, contact: credential,
      operation_ref: SecureRandom.uuid, event_name: "released",
    )
  end

  def surface
    case actor
    when Client then "app"
    when Operator then "org"
    else raise ArgumentError, "unsupported credential removal actor"
    end
  end

  def terminal?
    case credential
    when ClientPasskey then [ClientPasskeyStatus::REVOKED, ClientPasskeyStatus::DELETED].include?(credential.status_id)
    when OperatorPasskey then credential.status_id == OperatorPasskeyStatus::REVOKED
    when ClientTotpCredential then credential.revoked? || credential.deleted?
    when ClientEmail, ClientTelephone then credential.binding_released?
    else raise ArgumentError, "unsupported removal credential"
    end
  end

  def removable?
    case credential
    when ClientPasskey, OperatorPasskey then AuthMethodGuard.can_remove_passkey?(actor, credential)
    when ClientTotpCredential then AuthMethodGuard.can_remove_totp?(actor, credential)
    when ClientEmail then AuthMethodGuard.can_remove_email?(actor, credential)
    when ClientTelephone then AuthMethodGuard.can_remove_telephone?(actor, credential)
    else raise ArgumentError, "unsupported removal credential"
    end
  end

  def remove_credential!
    case credential
    when ClientPasskey, OperatorPasskey
      PasskeyAuditOutbox.record_for!(
        passkey: credential,
        event_type: "passkey.removed",
        surface: surface,
        actor_ref: actor.public_id,
        operation_ref: request&.request_id || SecureRandom.uuid,
        occurred_at: actor.class.database_now,
      )
      credential.destroy!
    when ClientTotpCredential then credential.update!(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::DELETED)
    when ClientEmail
      credential.release_binding!(at: ClientEmail.database_now)
      credential.update!(user_email_status_id: ClientEmailStatus::DELETED)
    when ClientTelephone
      credential.release_binding!(at: ClientTelephone.database_now)
      credential.update!(user_identity_telephone_status_id: ClientTelephoneStatus::DELETED)
    else raise ArgumentError, "unsupported removal credential"
    end
  end
end
