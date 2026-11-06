# frozen_string_literal: true

class IdentityTotpNameCommitter
  class Denied < StandardError; end

  class DependencyFailure < StandardError; end

  class InvalidTitle < ArgumentError; end

  class << self
    public

    def call!(actor:, token: nil, credential:, title:, step_up_evidence: nil)
      new(actor:, supplied_token: token, credential:, title:, evidence: step_up_evidence).call!
    end
  end

  def initialize(actor:, supplied_token:, credential:, title:, evidence:)
    @actor = actor
    @supplied_token = supplied_token
    @credential = credential
    @title = title
    @evidence = evidence
  end

  public

  def call!
    validate_binding!
    principal_connection = AppZenithRecord.lease_connection
    op_connection = OpBaseAppRecord.lease_connection
    ensure_outermost_transactions!(principal_connection:, op_connection:)

    perform_commit!(principal_connection:, op_connection:)
  rescue TokenStatusManagement::StepUpEvidenceUnavailable, ActiveRecord::RecordNotFound,
         ActiveRecord::StaleObjectError => e
    raise Denied, e.message
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionTimeoutError,
         ActiveRecord::StatementInvalid, ActiveRecord::SQLWarning => e
    principal_connection&.throw_away!
    raise DependencyFailure, "TOTP rename storage is unavailable: #{e.class.name}"
  end

  private

  attr_reader :actor, :supplied_token, :credential, :title, :evidence

  def perform_commit!(principal_connection:, op_connection:)

    principal_commit_confirmed = false
    committed_credential = nil
    OpBaseAppRecord.connected_to(role: :writing) do
      # Begin without acquiring OP row locks. The principal transaction then locks the actor
      # before the OP device, root and grant locks; its commit completes while those locks remain.
      OpBaseAppRecord.transaction do
        AppZenithRecord.connected_to(role: :writing) do
          AppZenithRecord.transaction do
            actor.with_lock do
              raise Denied, "TOTP rename actor is unavailable" unless actor.login_allowed? && !actor.deactivated?

              owned = ClientTotpCredential.lock.find_by(
                id: credential.id, public_id: credential.public_id, user_id: actor.id,
              )
              unless owned && ClientTotpCredentialPolicy.new(owned, user: actor).apply(:update?)
                raise Denied, "TOTP rename credential is unavailable"
              end

              token = resolve_evidenced_token!
              owned.assign_attributes(title:)
              changed = owned.has_changes_to_save?
              raise ActiveRecord::RecordInvalid, owned if changed && !owned.valid?

              lock_and_authorize!(token, owned)
              owned.save! if changed
              committed_credential = owned
            end
          end
        end
        principal_commit_confirmed = true
      end
    end

    committed_credential
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionTimeoutError,
         ActiveRecord::StatementInvalid, ActiveRecord::SQLWarning => e
    op_connection&.throw_away!
    if principal_commit_confirmed
      Rails.logger.warn(JitLogEvent.format("totp.rename.op_release_failed", reason_code: "op_release_failed"))
      return committed_credential
    end

    principal_connection&.throw_away!
    raise DependencyFailure, "TOTP rename commit outcome is not confirmed: #{e.class.name}"
  end

  def resolve_evidenced_token!
    unless evidence.is_a?(StepUpEvidenceValue) && evidence.sid.is_a?(String) && evidence.sid.present?
      raise Denied, "TOTP rename evidence is unavailable"
    end

    grant = OpAppGrant.find_by(public_id: evidence.sid, oidc_client_id: "base-app-ww")
    token = grant && actor.client_tokens.find_by(id: grant.client_token_id)
    raise Denied, "TOTP rename evidence does not identify the current owner root" unless token
    if supplied_token && (!supplied_token.is_a?(ClientToken) || supplied_token.id != token.id)
      raise Denied, "TOTP rename root does not match the evidence"
    end

    token
  end

  def lock_and_authorize!(token, owned)
    device = token.device_session_record!
    device.with_lock do
      unless device.usable? && device.user_id == actor.id && token.user_id == actor.id
        raise Denied, "TOTP name device session is unavailable"
      end

      token.with_lock do
        unless token.device_session_id == device.id && device.current_refresh_token_id == token.id
          raise Denied, "TOTP name session binding changed"
        end

        policy = ClientTotpCredentialPolicy.new(owned, user: actor)
        authorized = StepUpEvidenceVerifier.call(evidence:, actor:, token:) && policy.apply(:update?)
        raise Denied, "TOTP rename requires current Step-Up" unless authorized
      end
    end
  end

  def validate_binding!
    unless actor.is_a?(Client) && actor.persisted? &&
        (supplied_token.nil? || (supplied_token.is_a?(ClientToken) && supplied_token.persisted?)) &&
        credential.is_a?(ClientTotpCredential) && credential.persisted? && credential.user_id == actor.id &&
        (title.nil? || title.is_a?(String))
      raise Denied, "TOTP rename requires a bound app actor, session and credential"
    end
    raise InvalidTitle, "TOTP title must be 32 characters or fewer" if (title&.length || 0) > 32
  end

  def ensure_outermost_transactions!(principal_connection:, op_connection:)
    return if principal_connection.open_transactions.zero? && op_connection.open_transactions.zero?

    raise DependencyFailure, "TOTP rename must own the principal and OP transactions"
  end
end
