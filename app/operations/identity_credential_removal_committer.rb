# frozen_string_literal: true

# Caller supplies an authorized, owner-scoped record. The owner lock serializes inventory
# decisions with registration and Base finalization. Passkeys are current-state credentials:
# successful user removal physically deletes the row and records the stable audit fact in the
# principal-side outbox before the delete commits.
class IdentityCredentialRemovalCommitter
  # An enclosing OP transaction would defer the Ticket invalidation while the independent
  # Zenith credential mutation commits. Refuse instead of silently relying on a savepoint.
  class TransactionConflict < ArgumentError; end

  class DependencyFailure < StandardError; end

  class << self
    public

    def call!(actor:, credential:, current_session:, step_up_evidence: nil, actor_context: nil, request: nil)
      new(
        actor: actor, credential: credential, current_session: current_session,
        step_up_evidence: step_up_evidence, actor_context: actor_context, request: request,
      ).call!
    end
  end

  public

  def initialize(actor:, credential:, current_session:, step_up_evidence: nil, actor_context: nil, request: nil)
    @actor = actor
    @credential = credential
    @current_session = current_session
    @step_up_evidence = step_up_evidence
    @actor_context = actor_context
    @request = request
  end

  def call!
    return remove_rp_local_passkey! if current_session.nil?

    remove_with_root_session!
  end

  private

  def remove_with_root_session!
    validate_binding!
    require_independent_ticket_commit!
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
                return false unless passkey_management_authorized? && step_up_evidence_authorized?

                # Ticket invalidation precedes principal mutation. A separate-DB failure can
                # invalidate the session while retaining the credential, but cannot preserve stale authority.
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
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
    raise DependencyFailure, "Credential removal storage is unavailable: #{e.class}"
  end

  attr_reader :actor, :credential, :current_session, :step_up_evidence, :actor_context, :request

  def remove_rp_local_passkey!
    principal_record, op_record, passkey_class, token_class, grant_class, owner_key, client_id =
      rp_local_passkey_boundary!
    validate_rp_local_passkey_binding!(passkey_class:, owner_key:)
    unless step_up_evidence.is_a?(StepUpEvidenceValue) && step_up_evidence.sid.is_a?(String) &&
        step_up_evidence.sid.present?
      raise ArgumentError, "RP-local passkey removal requires Step-Up evidence"
    end

    principal_connection = principal_record.lease_connection
    op_connection = op_record.lease_connection
    ensure_rp_local_outermost_transactions!(principal_connection:, op_connection:)

    prepared = prepare_passkey_removal!(
      principal_record:, op_record:, passkey_class:, token_class:, grant_class:, owner_key:, client_id:,
    )
    return false unless prepared

    commit_rp_local_passkey_removal!(
      principal_record:, op_record:, passkey_class:, token_class:, grant_class:, owner_key:, client_id:,
    )
  end

  def commit_rp_local_passkey_removal!(principal_record:, op_record:, passkey_class:, token_class:, grant_class:,
                                       owner_key:, client_id:)
    principal_connection = principal_record.lease_connection
    op_connection = op_record.lease_connection
    operation_ref = SecureRandom.uuid
    principal_commit_confirmed = false
    op_record.connected_to(role: :writing) do
      op_record.transaction do
        principal_record.connected_to(role: :writing) do
          principal_record.transaction do
            actor.with_lock do
              raise ArgumentError, "Passkey owner is unavailable" unless actor.login_allowed? && !actor.deactivated?

              owned = lock_owned_passkey!(passkey_class, owner_key)
              return false if terminal?(owned) || !removable?(owned)

              token = resolve_evidenced_token!(grant_class:, token_class:, client_id:)
              return false unless token && passkey_management_authorized_for?(owned, token)
              return false unless StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor:, token:)

              PasskeyAuditOutbox.record_for!(
                passkey: owned, event_type: "passkey.removed", surface:, actor_ref: actor.public_id,
                operation_ref:, occurred_at: principal_record.database_now,
              )
              owned.destroy!
            end
          end
        end
        principal_commit_confirmed = true
      end
    end
    true
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionTimeoutError,
         ActiveRecord::StatementInvalid, ActiveRecord::SQLWarning => e
    op_connection&.throw_away!
    if principal_commit_confirmed
      Rails.logger.warn(JitLogEvent.format("passkey.removal.op_release_failed", reason_code: "op_release_failed"))
      return true
    end

    principal_connection&.throw_away!
    return true if operation_ref && committed_passkey_removal?(operation_ref:, passkey_class:, owner_key:)

    raise DependencyFailure, "Passkey removal commit outcome is not confirmed: #{e.class.name}"
  rescue ActiveRecord::RecordNotFound, ActiveRecord::StaleObjectError => e
    raise ArgumentError, "Passkey removal target is unavailable: #{e.class.name}"
  end

  def prepare_passkey_removal!(principal_record:, op_record:, passkey_class:, token_class:, grant_class:, owner_key:,
                               client_id:)
    token = nil
    principal_record.connected_to(role: :writing) do
      principal_record.transaction do
        actor.with_lock do
          raise ArgumentError, "Passkey owner is unavailable" unless actor.login_allowed? && !actor.deactivated?

          owned = lock_owned_passkey!(passkey_class, owner_key)
          return false if terminal?(owned) || !removable?(owned)

          token = resolve_evidenced_token!(grant_class:, token_class:, client_id:)
          return false unless token

          verified =
            op_record.connected_to(role: :writing) do
              op_record.transaction do
                StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor:, token:)
              end
            end
          return false unless verified && passkey_management_authorized_for?(owned, token)

          # Invalidate step-up freshness and unfinished admissions before the credential commit,
          # while retaining the current root session. The final O-10 transaction rechecks the
          # current grant; if it has changed, the credential write is refused. These invalidations
          # remain if the later credential commit fails.
          CredentialSecurityTransition.call(
            actor:, current_session: token, reason: :mfa_level_changed, affected_surface: surface,
            revoke_other_sessions: false, request:,
          )
        end
      end
    end
    true
  end

  def rp_local_passkey_boundary!
    case [actor, credential]
    in [Client, ClientPasskey]
      [AppZenithRecord, OpBaseAppRecord, ClientPasskey, ClientToken, OpAppGrant, :user_id, "base-app-ww"]
    in [Operator, OperatorPasskey]
      [OrgZenithRecord, OpBaseOrgRecord, OperatorPasskey, OperatorToken, OpOrgGrant, :staff_id, "base-org-ww"]
    else
      raise ArgumentError, "RP-local credential removal supports only owned passkeys"
    end
  end

  def validate_rp_local_passkey_binding!(passkey_class:, owner_key:)
    valid_owner =
      case [actor, credential, owner_key]
      in [Client, ClientPasskey, :user_id] then credential.user_id == actor.id
      in [Operator, OperatorPasskey, :staff_id] then credential.staff_id == actor.id
      else false
      end
    raise ArgumentError, "Passkey removal binding mismatch" unless
      actor.persisted? && credential.is_a?(passkey_class) && credential.persisted? && valid_owner
  end

  def lock_owned_passkey!(passkey_class, owner_key)
    case actor
    when Client
      raise ArgumentError, "unsupported APP passkey removal owner" unless
        passkey_class == ClientPasskey && owner_key == :user_id

      ClientPasskey.lock.find_by!(id: credential.id, user_id: actor.id, external_id: credential.external_id)
    when Operator
      raise ArgumentError, "unsupported ORG passkey removal owner" unless
        passkey_class == OperatorPasskey && owner_key == :staff_id

      OperatorPasskey.lock.find_by!(id: credential.id, staff_id: actor.id, external_id: credential.external_id)
    else
      raise ArgumentError, "unsupported passkey removal owner"
    end
  end

  def resolve_evidenced_token!(grant_class:, token_class:, client_id:)
    grant = grant_class.find_by(public_id: step_up_evidence.sid, oidc_client_id: client_id)
    return unless grant

    token =
      case actor
      when Client
        raise ArgumentError, "unsupported APP passkey removal evidence boundary" unless
          grant.is_a?(OpAppGrant) && token_class == ClientToken

        ClientToken.find_by(id: grant.client_token_id)
      when Operator
        raise ArgumentError, "unsupported ORG passkey removal evidence boundary" unless
          grant.is_a?(OpOrgGrant) && token_class == OperatorToken

        OperatorToken.find_by(id: grant.operator_token_id)
      else
        raise ArgumentError, "unsupported passkey removal evidence boundary"
      end
    owner_matches =
      case [actor, token]
      in [Client, ClientToken] then token.user_id == actor.id
      in [Operator, OperatorToken] then token.staff_id == actor.id
      else false
      end
    owner_matches ? token : nil
  end

  def passkey_management_authorized_for?(passkey, token)
    policy =
      case [actor, passkey]
      in [Client, ClientPasskey] then ClientPasskeyPolicy.new(passkey, user: actor)
      in [Operator, OperatorPasskey] then OperatorPasskeyPolicy.new(passkey, user: actor)
      else raise ArgumentError, "unsupported passkey owner"
      end
    policy.apply(:destroy?) && policy.management_authorized?(token:, now: token.class.database_now)
  end

  def committed_passkey_removal?(operation_ref:, passkey_class:, owner_key:)
    outbox_class = PasskeyAuditOutbox.source_for(credential)
    receipt = outbox_class.exists?(
      operation_ref:, event_type: "passkey.removed", external_id: credential.external_id, actor_ref: actor.public_id,
    )
    credential_remaining =
      case actor
      when Client
        raise ArgumentError, "unsupported APP passkey receipt boundary" unless
          passkey_class == ClientPasskey && owner_key == :user_id

        ClientPasskey.exists?(id: credential.id, user_id: actor.id, external_id: credential.external_id)
      when Operator
        raise ArgumentError, "unsupported ORG passkey receipt boundary" unless
          passkey_class == OperatorPasskey && owner_key == :staff_id

        OperatorPasskey.exists?(id: credential.id, staff_id: actor.id, external_id: credential.external_id)
      else
        raise ArgumentError, "unsupported passkey receipt actor"
      end
    receipt && !credential_remaining
  end

  def ensure_rp_local_outermost_transactions!(principal_connection:, op_connection:)
    return if principal_connection.open_transactions.zero? && op_connection.open_transactions.zero?

    raise TransactionConflict, "RP-local passkey removal must own the principal and OP transactions"
  end

  # Ticket invalidation precedes the Zenith mutation, so the invalidation must own its commit.
  # Checked before any lock or evidence verification.
  def require_independent_ticket_commit!
    ticket = current_session.class.connection_class_for_self
    ticket.connected_to(role: :writing) do
      connection = ticket.lease_connection
      if connection.transaction_open?
        raise TransactionConflict, "credential removal requires an independent OP commit"
      end
    end
  end

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
    policy.apply(:destroy?) && policy.management_authorized?(
      token: current_session, now: current_session.class.database_now,
    )
  end

  def step_up_evidence_authorized?
    StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: current_session)
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

  def terminal?(candidate = credential)
    case candidate
    when ClientPasskey then [ClientPasskeyStatus::REVOKED, ClientPasskeyStatus::DELETED].include?(candidate.status_id)
    when OperatorPasskey then candidate.status_id == OperatorPasskeyStatus::REVOKED
    when ClientTotpCredential then candidate.revoked? || candidate.deleted?
    when ClientEmail, ClientTelephone then candidate.binding_released?
    else raise ArgumentError, "unsupported removal credential"
    end
  end

  def removable?(candidate = credential)
    case candidate
    when ClientPasskey, OperatorPasskey then AuthMethodGuard.can_remove_passkey?(actor, candidate)
    when ClientTotpCredential then AuthMethodGuard.can_remove_totp?(actor, candidate)
    when ClientEmail then AuthMethodGuard.can_remove_email?(actor, candidate)
    when ClientTelephone then AuthMethodGuard.can_remove_telephone?(actor, candidate)
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
