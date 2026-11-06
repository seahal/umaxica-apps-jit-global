# frozen_string_literal: true

# Commits a Base-owned passkey rename while the source owner locks the OP grant proved by the
# authenticated RP event. The RP does not supply an OP root token; the owner resolves it by `sid`.
class IdentityPasskeyNameCommitter
  class Denied < StandardError; end

  class DependencyFailure < StandardError; end

  class << self
    public

    def call!(actor:, token: nil, passkey:, description:, step_up_evidence: nil)
      new(actor:, supplied_token: token, passkey:, description:, evidence: step_up_evidence).call!
    end
  end

  def initialize(actor:, supplied_token:, passkey:, description:, evidence:)
    @actor = actor
    @supplied_token = supplied_token
    @passkey = passkey
    @description = description
    @evidence = evidence
  end

  public

  def call!
    validate_binding!
    operation_ref = SecureRandom.uuid
    principal_connection = nil
    op_connection = nil
    principal_commit_confirmed = false
    committed_passkey = nil
    changed = false

    case actor
    when Client
      principal_connection = AppZenithRecord.lease_connection
      op_connection = OpBaseAppRecord.lease_connection
      ensure_outermost_transactions!(principal_connection:, op_connection:)
      op_connection.transaction do
        AppZenithRecord.transaction do
          committed_passkey, changed = commit_app(operation_ref:)
        end
        principal_commit_confirmed = true
      end
    when Operator
      principal_connection = OrgZenithRecord.lease_connection
      op_connection = OpBaseOrgRecord.lease_connection
      ensure_outermost_transactions!(principal_connection:, op_connection:)
      op_connection.transaction do
        OrgZenithRecord.transaction do
          committed_passkey, changed = commit_org(operation_ref:)
        end
        principal_commit_confirmed = true
      end
    else
      raise ArgumentError, "unsupported passkey actor"
    end

    committed_passkey
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionTimeoutError,
         ActiveRecord::StatementInvalid, ActiveRecord::SQLWarning => e
    op_connection&.throw_away!
    if principal_commit_confirmed
      Rails.logger.warn(JitLogEvent.format("passkey.rename.op_release_failed", reason_code: "op_release_failed"))
      return committed_passkey
    end

    principal_connection&.throw_away!
    return committed_passkey if changed && committed_receipt?(operation_ref:)

    raise DependencyFailure, "Passkey rename commit outcome is not confirmed: #{e.class.name}"
  rescue ActiveRecord::RecordNotFound, ActiveRecord::StaleObjectError => e
    raise Denied, e.message
  end

  private

  attr_reader :actor, :supplied_token, :passkey, :description, :evidence

  def commit_app(operation_ref:)
    commit_owned_passkey(
      operation_ref:, record: AppZenithRecord, passkey_class: ClientPasskey, token_class: ClientToken,
      grant_class: OpAppGrant, outbox_class: ClientPasskeyAuditOutbox, surface: "app",
    )
  end

  def commit_org(operation_ref:)
    commit_owned_passkey(
      operation_ref:, record: OrgZenithRecord, passkey_class: OperatorPasskey, token_class: OperatorToken,
      grant_class: OpOrgGrant, outbox_class: OperatorPasskeyAuditOutbox, surface: "org",
    )
  end

  def commit_owned_passkey(operation_ref:, record:, passkey_class:, token_class:, grant_class:, outbox_class:, surface:)
    actor.with_lock do
      raise Denied, "Passkey owner is unavailable" unless actor.login_allowed? && !actor.deactivated?

      owned = lock_owned_passkey!(passkey_class)
      token = resolve_evidenced_token!(token_class:, grant_class:, surface:)
      policy = policy_for(token:, passkey: owned)
      owned.assign_attributes(description:)
      changed = owned.has_changes_to_save?
      raise ActiveRecord::RecordInvalid, owned if changed && !owned.valid?

      authorize_locked!(token:, policy:, passkey: owned)
      if changed
        owned.save!
        PasskeyAuditOutbox.record_for!(
          passkey: owned, event_type: "passkey.description_changed", surface:, actor_ref: actor.public_id,
          operation_ref:, occurred_at: record.database_now,
        )
        authorize_locked!(token:, policy:, passkey: owned)
      end
      [owned, changed]
    end
  end

  def lock_owned_passkey!(passkey_class)
    if actor.is_a?(Client) && passkey_class == ClientPasskey && passkey.is_a?(ClientPasskey)
      ClientPasskey.lock.find_by!(id: passkey.id, user_id: actor.id, external_id: passkey.external_id)
    elsif actor.is_a?(Operator) && passkey_class == OperatorPasskey && passkey.is_a?(OperatorPasskey)
      OperatorPasskey.lock.find_by!(id: passkey.id, staff_id: actor.id, external_id: passkey.external_id)
    else
      raise Denied, "Passkey owner binding does not match"
    end
  end

  def resolve_evidenced_token!(token_class:, grant_class:, surface:)
    unless evidence.is_a?(StepUpEvidenceValue) && evidence.sid.is_a?(String) && evidence.sid.present?
      raise Denied, "Passkey rename evidence is unavailable"
    end

    token =
      case actor
      when Client
        raise ArgumentError, "unsupported passkey evidence boundary" unless
          token_class == ClientToken && grant_class == OpAppGrant && surface == "app"

        grant = OpAppGrant.find_by(public_id: evidence.sid, oidc_client_id: "base-app-ww")
        grant && actor.client_tokens.find_by(id: grant.client_token_id)
      when Operator
        raise ArgumentError, "unsupported passkey evidence boundary" unless
          token_class == OperatorToken && grant_class == OpOrgGrant && surface == "org"

        grant = OpOrgGrant.find_by(public_id: evidence.sid, oidc_client_id: "base-org-ww")
        grant && actor.operator_tokens.find_by(id: grant.operator_token_id)
      else
        raise ArgumentError, "unsupported passkey evidence boundary"
      end

    raise Denied, "Passkey rename evidence does not identify the current owner root" unless token
    if supplied_token && (supplied_token.class != token_class || supplied_token.id != token.id)
      raise Denied, "Passkey rename root does not match the evidence"
    end

    token
  end

  def authorize_locked!(token:, policy:, passkey:)
    now = token.class.database_now
    authorized = StepUpEvidenceVerifier.call(evidence:, actor:, token:) &&
      policy.apply(:update?) && policy.management_authorized?(token:, now:) && active_passkey?(passkey)
    raise Denied, "Passkey rename requires current Step-Up" unless authorized
  end

  def policy_for(token:, passkey:)
    case [actor, token, passkey]
    in [Client, ClientToken, ClientPasskey] if token.user_id == actor.id && passkey.user_id == actor.id
      ClientPasskeyPolicy.new(passkey, user: actor)
    in [Operator, OperatorToken, OperatorPasskey] if token.staff_id == actor.id && passkey.staff_id == actor.id
      OperatorPasskeyPolicy.new(passkey, user: actor)
    else
      raise Denied, "Passkey rename binding mismatch"
    end
  end

  def active_passkey?(candidate)
    case candidate
    when ClientPasskey
      candidate.status_id == ClientPasskeyStatus::ACTIVE && candidate.accessible?
    when OperatorPasskey
      candidate.status_id == OperatorPasskeyStatus::ACTIVE
    else
      raise Denied, "unsupported passkey"
    end
  end

  def committed_receipt?(operation_ref:)
    case [actor, passkey]
    in [Client, ClientPasskey]
      ClientPasskeyAuditOutbox.exists?(
        operation_ref:, event_type: "passkey.description_changed", external_id: passkey.external_id,
        actor_ref: actor.public_id,
      ) && ClientPasskey.find_by(id: passkey.id, user_id: actor.id, external_id: passkey.external_id)
    in [Operator, OperatorPasskey]
      OperatorPasskeyAuditOutbox.exists?(
        operation_ref:, event_type: "passkey.description_changed", external_id: passkey.external_id,
        actor_ref: actor.public_id,
      ) && OperatorPasskey.find_by(id: passkey.id, staff_id: actor.id, external_id: passkey.external_id)
    else
      raise ArgumentError, "unsupported passkey receipt boundary"
    end
  end

  def validate_binding!
    valid =
      case [actor, passkey]
      in [Client, ClientPasskey] then passkey.user_id == actor.id
      in [Operator, OperatorPasskey] then passkey.staff_id == actor.id
      else false
      end
    raise Denied, "Passkey rename binding mismatch" unless actor.persisted? && passkey.persisted? && valid
  end

  def ensure_outermost_transactions!(principal_connection:, op_connection:)
    return if principal_connection.open_transactions.zero? && op_connection.open_transactions.zero?

    raise DependencyFailure, "Passkey rename must own the principal and OP transactions"
  end
end
