# frozen_string_literal: true

# Caller supplies an authorized, owner-scoped record. The owner lock serializes inventory
# decisions with registration and Base finalization; retained terminal rows preserve history.
class IdentityCredentialRemovalCommitter
  class << self
    public

    def call!(actor:, credential:, current_session:, request: nil)
      new(actor: actor, credential: credential, current_session: current_session, request: request).call!
    end
  end

  public

  def initialize(actor:, credential:, current_session:, request: nil)
    @actor = actor
    @credential = credential
    @current_session = current_session
    @request = request
  end

  def call!
    validate_binding!
    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        credential.with_lock do
          current_session.class.connection_class_for_self.connected_to(role: :writing) do
            current_session.with_lock do
              validate_binding!
              unless current_session.currently_usable?(current_session.class.database_now)
                raise ArgumentError, "credential removal session is unavailable"
              end
              if current_session.is_a?(OperatorToken) && current_session.emergency_authentication_context?
                raise ArgumentError, "credential removal requires a Normal session"
              end
              return false if terminal? || !removable?

              # Ticket invalidation precedes principal mutation. A separate-DB failure can
              # remove freshness while retaining the credential, but cannot preserve stale authority.
              CredentialSecurityTransition.call(
                actor: actor, current_session: current_session, reason: :mfa_level_changed,
                affected_surface: surface, revoke_other_sessions: false, request: request,
              )
              mark_terminal!
              true
            end
          end
        end
      end
    end
  end

  private

  attr_reader :actor, :credential, :current_session, :request

  def validate_binding!
    owner_matches =
      case [actor, credential, current_session]
      in [Client, ClientPasskey | ClientTotpCredential, ClientToken]
        credential.user_id == actor.id && current_session.user_id == actor.id
      in [Visitor, VisitorPasskey, VisitorToken]
        credential.visitor_id == actor.id && current_session.visitor_id == actor.id
      in [Operator, OperatorPasskey, OperatorToken]
        credential.staff_id == actor.id && current_session.staff_id == actor.id
      else false
      end
    raise ArgumentError, "credential removal binding mismatch" unless owner_matches
    return if actor.persisted? && credential.persisted? && current_session.persisted?

    raise ArgumentError, "credential removal requires persisted records"
  end

  def surface
    case actor
    when Client then "app"
    when Visitor then "com"
    when Operator then "org"
    else raise ArgumentError, "unsupported credential removal actor"
    end
  end

  def terminal?
    case credential
    when ClientPasskey then [ClientPasskeyStatus::REVOKED, ClientPasskeyStatus::DELETED].include?(credential.status_id)
    when VisitorPasskey then [VisitorPasskeyStatus::REVOKED, VisitorPasskeyStatus::DELETED].include?(credential.status_id)
    when OperatorPasskey then credential.status_id == OperatorPasskeyStatus::REVOKED
    when ClientTotpCredential then credential.revoked? || credential.deleted?
    else raise ArgumentError, "unsupported removal credential"
    end
  end

  def removable?
    case credential
    when ClientPasskey, VisitorPasskey, OperatorPasskey then AuthMethodGuard.can_remove_passkey?(actor, credential)
    when ClientTotpCredential then AuthMethodGuard.can_remove_totp?(actor, credential)
    else raise ArgumentError, "unsupported removal credential"
    end
  end

  def mark_terminal!
    case credential
    when ClientPasskey then credential.update!(status_id: ClientPasskeyStatus::DELETED)
    when VisitorPasskey then credential.update!(status_id: VisitorPasskeyStatus::DELETED)
    when OperatorPasskey then credential.update!(status_id: OperatorPasskeyStatus::REVOKED)
    when ClientTotpCredential then credential.update!(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::DELETED)
    else raise ArgumentError, "unsupported removal credential"
    end
  end
end
