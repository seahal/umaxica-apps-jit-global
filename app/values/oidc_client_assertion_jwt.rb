# typed: false
# frozen_string_literal: true

module OidcClientAssertionJwt
  module_function

  ASSERTION_TYPE = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
  TOKEN_TYPE = "oidc-client-assertion+jwt"
  TTL = 5.minutes
  VerificationResult =
    Data.define(:authenticated, :step_up_claims_state, :step_up_expectation) do
      def authenticated? = authenticated

      def step_up_claims_present? = step_up_claims_state != :none
    end

  def issue(client_id:, token_url:, now: Time.current, jti: SecureRandom.uuid, step_up_expectation: nil)
    validate_step_up_expectation!(step_up_expectation)
    issue_with_configured_key(
      client_id: client_id,
      token_url: token_url,
      now: now,
      jti: jti,
      step_up_expectation: step_up_expectation,
    )
  rescue JitSecurityJwtRegistry::ConfigurationError
    return nil unless refresh_local_key_material!(client_id: client_id)

    begin
      issue_with_configured_key(
        client_id: client_id,
        token_url: token_url,
        now: now,
        jti: jti,
        step_up_expectation: step_up_expectation,
      )
    rescue JitSecurityJwtRegistry::ConfigurationError
      nil
    end
  end

  def issue_with_configured_key(client_id:, token_url:, now:, jti:, step_up_expectation:)
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
    if step_up_expectation
      payload["step_up_grant"] = step_up_expectation.grant
      payload["step_up_sub"] = step_up_expectation.subject
    end

    JitSecurityJwtKeyring.encode(payload, typ: TOKEN_TYPE, issuer_id: issuer_id)
  end

  def verify(client_id:, assertion:, token_url:, now: Time.current)
    return rejected_verification unless assertion.is_a?(String) && assertion.present?

    header = JitSecurityJwtKeyring.parse_header(assertion)
    return rejected_verification unless header["alg"] == JitSecurityJwtRegistry::ALGORITHM
    return rejected_verification unless header["typ"] == TOKEN_TYPE

    namespace = OidcClientRegistry.jwt_namespace_for(client_id)
    return rejected_verification if namespace.blank?

    public_key = JitSecurityJwtRegistry.public_key_for("oidc_client:#{namespace}", header["kid"])
    return rejected_verification unless public_key

    payload, = JWT.decode(
      assertion,
      public_key,
      true,
      algorithms: [JitSecurityJwtRegistry::ALGORITHM],
      required_claims: %w(iss sub aud exp iat jti typ),
      leeway: AuthenticationJwtConfiguration.leeway_seconds,
      verify_iat: { leeway: AuthenticationJwtConfiguration.leeway_seconds },
      verify_expiration: true,
      verify_aud: true,
      aud: token_url.to_s,
    )

    return rejected_verification unless payload["iss"] == client_id.to_s &&
      payload["sub"] == client_id.to_s && payload["typ"] == TOKEN_TYPE && now.to_i < payload["exp"].to_i
    return rejected_verification unless consume_jti?(
      client_id: client_id,
      jti: payload["jti"],
      exp: payload["exp"],
      now: now,
    )

    expectation_result = step_up_expectation_for(payload)
    VerificationResult.new(
      authenticated: true,
      step_up_claims_state: expectation_result.fetch(:state),
      step_up_expectation: expectation_result.fetch(:value),
    )
  rescue JWT::DecodeError, JitSecurityJwtRegistry::ConfigurationError
    rejected_verification
  end

  def valid?(client_id:, assertion:, token_url:, now: Time.current)
    verify(client_id:, assertion:, token_url:, now:).authenticated?
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

  def validate_step_up_expectation!(expectation)
    return if expectation.nil? || expectation.is_a?(OidcClientAssertionStepUpExpectationValue)

    raise ArgumentError, "step_up_expectation must be an OIDC client assertion value"
  end

  def rejected_verification
    VerificationResult.new(
      authenticated: false,
      step_up_claims_state: :none,
      step_up_expectation: nil,
    )
  end

  def step_up_expectation_for(payload)
    grant_present = payload.key?("step_up_grant")
    subject_present = payload.key?("step_up_sub")
    return { state: :none, value: nil } unless grant_present || subject_present
    return { state: :invalid, value: nil } unless grant_present && subject_present

    grant = payload["step_up_grant"]
    subject = payload["step_up_sub"]
    return { state: :invalid, value: nil } unless grant.is_a?(String) && grant.present? &&
      subject.is_a?(String) && subject.present?

    {
      state: :valid,
      value: OidcClientAssertionStepUpExpectationValue.new(grant:, subject:),
    }
  end

  private_class_method :issue_with_configured_key, :consume_jti?, :refresh_local_key_material!,
                       :validate_step_up_expectation!, :rejected_verification, :step_up_expectation_for
end
