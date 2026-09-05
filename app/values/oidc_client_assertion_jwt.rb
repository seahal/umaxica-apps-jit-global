# typed: false
# frozen_string_literal: true

module OidcClientAssertionJwt
  module_function

  ASSERTION_TYPE = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
  TOKEN_TYPE = "oidc-client-assertion+jwt"
  TTL = 5.minutes

  def issue(client_id:, token_url:, now: Time.current, jti: SecureRandom.uuid)
    issue_with_configured_key(client_id: client_id, token_url: token_url, now: now, jti: jti)
  rescue JitSecurityJwtRegistry::ConfigurationError
    return nil unless refresh_local_key_material!(client_id: client_id)

    begin
      issue_with_configured_key(client_id: client_id, token_url: token_url, now: now, jti: jti)
    rescue JitSecurityJwtRegistry::ConfigurationError
      nil
    end
  end

  def issue_with_configured_key(client_id:, token_url:, now:, jti:)
    namespace = OidcClientRegistry.jwt_namespace_for(client_id)
    return nil if namespace.blank?

    issuer_id = "oidc_client:#{namespace}"
    payload = {
      "iss" => client_id.to_s,
      "sub" => client_id.to_s,
      "aud" => token_url.to_s,
      "jti" => jti,
      "iat" => now.to_i,
      "exp" => (now + TTL).to_i,
      "typ" => TOKEN_TYPE,
    }

    JitSecurityJwtKeyring.encode(payload, issuer_id: issuer_id)
  end

  def valid?(client_id:, assertion:, token_url:, now: Time.current)
    header = JitSecurityJwtKeyring.parse_header(assertion)
    return false unless header["alg"] == JitSecurityJwtRegistry::ALGORITHM
    return false unless header["typ"] == TOKEN_TYPE

    namespace = OidcClientRegistry.jwt_namespace_for(client_id)
    return false if namespace.blank?

    public_key = JitSecurityJwtRegistry.public_key_for("oidc_client:#{namespace}", header["kid"])
    return false unless public_key

    payload, = JWT.decode(
      assertion,
      public_key,
      true,
      algorithms: [JitSecurityJwtRegistry::ALGORITHM],
      required_claims: %w(iss sub aud exp iat jti typ),
      leeway: AuthenticationJwtConfiguration.leeway_seconds,
      verify_iat: true,
      verify_exp: true,
      verify_aud: true,
      aud: token_url.to_s,
    )

    payload["iss"] == client_id.to_s &&
      payload["sub"] == client_id.to_s &&
      payload["typ"] == TOKEN_TYPE &&
      now.to_i < payload["exp"].to_i &&
      consume_jti?(
        client_id: client_id,
        jti: payload["jti"],
        exp: payload["exp"],
        now: now,
      )
  rescue JWT::DecodeError, JitSecurityJwtRegistry::ConfigurationError
    false
  end

  # A client assertion is single-use. The record of that use is replay-prevention
  # state, so it lives in PostgreSQL alongside the other consumed JTIs rather than
  # in Rails.cache: a cache is allowed to evict, and an eviction here would re-open
  # the replay window for the remainder of the assertion's lifetime. The unique
  # index on (purpose, issuer, jti_digest) is what makes the check atomic -- a
  # concurrent second use loses the insert and is rejected.
  #
  # Fails closed. An unavailable database rejects the assertion rather than
  # accepting one whose uniqueness could not be established.
  def consume_jti?(client_id:, jti:, exp:, now:)
    return false if jti.blank?

    expires_at = Time.zone.at(exp.to_i + AuthenticationJwtConfiguration.leeway_seconds)
    return false unless expires_at > now

    SecurityConsumedJti.consume!(
      purpose: SecurityConsumedJti::PURPOSES.fetch(:oidc_client_assertion),
      issuer: client_id,
      jti: jti,
      expires_at: expires_at,
    )
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.client_assertion.replay_record_unavailable",
        error_class: e.class.name,
        error_message: e.message,
      ),
    )
    false
  end

  def refresh_local_key_material!(client_id:)
    return false unless Rails.env.local?
    return false unless defined?(JitSecurityJwtLocalKeysetInstaller)

    namespace = OidcClientRegistry.jwt_namespace_for(client_id)
    return false if namespace.blank?

    JitSecurityJwtLocalKeysetInstaller.install!
    JitSecurityJwtRegistry.reload!
    JitSecurityJwtRegistry.private_key_for("oidc_client:#{namespace}").present?
  end

  private_class_method :issue_with_configured_key, :consume_jti?, :refresh_local_key_material!
end
