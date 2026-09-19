# typed: false
# frozen_string_literal: true

module AuthorizationTokenClaims
  module_function

  def build(resource:, session_id: nil, session_public_id: nil, oidc_sid: nil, oidc_jti: nil, resource_type:,
            issued_at:, access_token_ttl:, expires_at: nil, scopes: nil, acr: nil, amr: nil, dpop_jkt: nil,
            issuer: nil, audiences: nil, subject: nil, auth_time: nil, step_up_until: nil, client_id: nil,
            authentication_context: nil)
    sid = oidc_sid.presence || session_public_id || session_id
    issued_at_seconds = timestamp_value(issued_at)
    expires_at_seconds = timestamp_value(expires_at || (issued_at + access_token_ttl))
    context = AuthenticationContextValue.for(authentication_context.presence || AuthenticationContextValue::NORMAL_KEY)
    # Session capabilities narrow the token's authorization scopes; they never
    # add one. An Emergency session therefore carries a subset of what the same
    # Operator would receive normally, and DB role membership stays the
    # authority for everything the subset still permits.
    scopes_value = context.constrain_scopes(scopes || resolve_scopes(resource_type, resource))

    payload = {
      "iat" => issued_at_seconds,
      "nbf" => issued_at_seconds,
      "exp" => expires_at_seconds,
      "jti" => oidc_jti.presence || JitSecurityJwtJtiGenerator.generate,
      "sub" => (subject.presence || resource.id).to_s,
      "iss" => issuer.presence || AuthenticationJwtConfiguration.issuer,
      "aud" => audiences.presence || AuthenticationJwtConfiguration.audiences(resource_type),
      "client_id" => client_id.presence || AuthenticationJwtConfiguration.client_id(resource_type),
      "scope" => Array(scopes_value).map(&:to_s).join(" "),
      "acr" => normalize_acr(acr),
      # Always present, so a downstream consumer distinguishes "this build does
      # not mint the claim" from "this session is Normal" by the token's age
      # alone, never by guessing.
      AuthenticationContextValue::CLAIM => context.to_s,
    }
    payload["amr"] = Array(amr) if amr.present?
    payload["sid"] = sid if sid.present?
    payload["auth_time"] = timestamp_value(auth_time) if auth_time.present?
    payload["step_up_until"] = timestamp_value(step_up_until) if step_up_until.present?
    payload["cnf"] = { "jkt" => dpop_jkt } if dpop_jkt.present?
    payload
  end

  def normalize_acr(acr)
    return "aal1" if acr.blank?

    acr.to_s.downcase
  end

  def subject(payload)
    payload&.dig("sub")
  end

  def resource_type(payload)
    SecurityJwtRfc9068AccessTokenProfile.resource_type_from_scope(payload)
  end

  def session_id(payload)
    payload&.dig("sid")
  end

  def jti(payload)
    payload&.dig("jti")
  end

  def scopes(payload)
    SecurityJwtRfc9068AccessTokenProfile.parse_scopes(payload)
  end

  # The trusted authentication context of a decoded access token. A payload
  # with no claim is a session minted before Emergency Access existed, which
  # was Normal; an unrecognised value resolves to the capability-less UNKNOWN
  # context rather than to Normal.
  def authentication_context(payload)
    AuthenticationContextValue.from_claims(payload)
  end

  def audiences(payload)
    payload&.dig("aud") || []
  end

  def client_id(payload)
    payload&.dig("client_id")
  end

  def timestamp_value(value)
    if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
      return Integer(value.strftime("%s"), 10)
    end

    return value if value.is_a?(Integer)
    return Integer(value, 10) if value.is_a?(Numeric)

    Integer(value.to_s, 10)
  end
  private_class_method :timestamp_value

  # Returns default scopes based on resource type
  # @param resource_type [String] 'client', 'operator', or 'visitor'
  # @param resource [AuthorizationClient/AuthorizationOperator/AuthorizationVisitor] the authenticated resource
  # @return [Array<String>] list of scopes
  def resolve_scopes(resource_type, _resource)
    base_scopes = ["authenticated", "domain:#{resource_type}"]

    case resource_type.to_s
    when "client", "visitor"
      base_scopes + ["read:self", "write:self"]
    when "operator"
      base_scopes + ["read:org", "write:org"]
    else
      base_scopes
    end
  end
  private_class_method :resolve_scopes
end
