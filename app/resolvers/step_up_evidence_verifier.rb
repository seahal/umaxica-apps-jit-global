# frozen_string_literal: true

# Rechecks a verified OP access-token event against the live Base grant at a write boundary.
# Call from the writer's transaction so the root and grant locks remain held through its commit.
class StepUpEvidenceVerifier
  STEP_UP_ACR = StepUpEvidenceResolver::STEP_UP_ACR

  class << self
    public

    def call(evidence:, actor:, token:)
      new(evidence:, actor:, token:).call
    end
  end

  public

  def initialize(evidence:, actor:, token:)
    @evidence = evidence
    @actor = actor
    @token = token
  end

  def call
    record_class, grant_class, device_class, client_id, resource_type = token_boundary
    return false unless record_class
    return false unless valid_request?(client_id:, resource_type:)

    record_class.connected_to(role: :writing) do
      require_writer_transaction!
      verify_locked_evidence(record_class:, grant_class:, device_class:, client_id:, resource_type:)
    end
  end

  private

  attr_reader :evidence, :actor, :token

  def token_boundary
    case [actor, token]
    in [Client, ClientToken]
      [OpBaseAppRecord, OpAppGrant, ClientDeviceSession, "base-app-ww", "client"]
    in [Operator, OperatorToken]
      [OpBaseOrgRecord, OpOrgGrant, OperatorDeviceSession, "base-org-ww", "operator"]
    else
      nil
    end
  end

  def valid_request?(client_id:, resource_type:)
    valid_evidence_shape?(client_id:, resource_type:) && actor.login_allowed? &&
      !actor.deactivated? && token_actor_matches?(actor)
  end

  def require_writer_transaction!
    transaction_open =
      token.class.connection_pool.with_connection do |connection|
        connection.open_transactions.positive?
      end
    return if transaction_open

    raise ArgumentError, "step-up evidence must be checked inside the writer transaction"
  end

  def verify_locked_evidence(record_class:, grant_class:, device_class:, client_id:, resource_type:)
    device = device_class.lock.find_by(id: token.device_session_id)
    return false unless device && device_actor_matches?(device)

    current = token.class.lock.find_by(id: token.id, public_id: token.public_id)
    return false unless current && token_actor_matches?(actor, current)

    client = OidcClientRegistry.find!(client_id)
    grant = grant_for_evidence(grant_class:, client_id:, current:, device:)
    return false unless grant

    # The grant lock may wait behind refresh, logout or another owner mutation. Evaluate the
    # freshness deadline only after every authority lock has been acquired.
    now = record_class.database_now
    return false unless current.active_status?(now) && evidence.current?(now: now.to_time)
    return false unless device.usable? && device.current_refresh_token_id == current.id
    return false unless current.strict_authentication_context_value.step_up_permitted?
    return false unless current_grant?(grant:, current:, now:)
    return false unless dpop_unbound?(current:, device:, grant:)
    return false unless evidence.client_id == client_id && evidence.aud == [client.aud]
    return false unless secure_equal?(evidence.sub, OidcSubject.for(actor, resource_type:))

    grant_event_matches?(grant)
  end

  def current_grant?(grant:, current:, now:)
    grant.active?(now) && grant.authentication_epoch == current.authentication_epoch
  end

  def dpop_unbound?(current:, device:, grant:)
    current.dpop_jkt.blank? && device.dpop_jkt.blank? && grant.dpop_jkt.blank?
  end

  def valid_evidence_shape?(client_id:, resource_type:)
    evidence.is_a?(StepUpEvidenceValue) && evidence.acr == STEP_UP_ACR &&
      evidence.auth_time.is_a?(Integer) && evidence.amr.is_a?(Array) &&
      evidence.amr.all? { |method| method.is_a?(String) && method.present? } &&
      evidence_identifiers_valid? &&
      evidence.aud.is_a?(Array) && evidence.aud.all? { |audience| audience.is_a?(String) && audience.present? } &&
      OidcSubject.for(actor, resource_type:) == evidence.sub && evidence.client_id == client_id
  end

  def evidence_identifiers_valid?
    [evidence.sid, evidence.sub, evidence.client_id, evidence.jti].all? do |value|
      value.is_a?(String) && value.present?
    end
  end

  # AMR is compared only as part of the persisted event snapshot; it does not decide authorization.
  def grant_event_matches?(grant)
    grant.oidc_auth_time&.to_i == evidence.auth_time && secure_equal?(grant.oidc_acr.to_s, evidence.acr) &&
      parse_stored_amr(grant.oidc_amr) == evidence.amr && secure_equal?(grant.oidc_jti.to_s, evidence.jti)
  end

  def parse_stored_amr(value)
    parsed = JSON.parse(value.to_s)
    return unless parsed.is_a?(Array) && parsed.all? { |method| method.is_a?(String) && method.present? }

    parsed
  rescue JSON::ParserError
    nil
  end

  def grant_for_evidence(grant_class:, client_id:, current:, device:)
    attributes = {
      public_id: evidence.sid,
      oidc_client_id: client_id,
      device_session_id: device.id,
    }
    if grant_class == OpAppGrant && current.is_a?(ClientToken)
      attributes[:client_token_id] = current.id
    elsif grant_class == OpOrgGrant && current.is_a?(OperatorToken)
      attributes[:operator_token_id] = current.id
    else
      raise ArgumentError, "step-up evidence grant and root token classes do not match"
    end
    grant_class.lock.find_by(attributes)
  end

  def token_actor_matches?(expected_actor, candidate = token)
    case [candidate, expected_actor]
    in [ClientToken, Client] then candidate.user_id == expected_actor.id
    in [OperatorToken, Operator] then candidate.staff_id == expected_actor.id
    else false
    end
  end

  def device_actor_matches?(device)
    case [device, actor]
    in [ClientDeviceSession, Client] then device.user_id == actor.id
    in [OperatorDeviceSession, Operator] then device.staff_id == actor.id
    else false
    end
  end

  def secure_equal?(actual, expected)
    actual.is_a?(String) && expected.is_a?(String) && actual.bytesize == expected.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(actual, expected)
  end
end
