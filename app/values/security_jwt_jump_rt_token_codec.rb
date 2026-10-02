# typed: false
# frozen_string_literal: true

class SecurityJwtJumpRtTokenCodec
  ALGORITHM = "ES384"
  TOKEN_TYPE = "JWT"
  TOKEN_SUBJECT = "jump-redirect"
  SCHEMA = 1
  # Schema 1 Jump RTs are reusable navigation instructions. "reuse" is the only valid value;
  # Jump never provides single-use semantics.
  REPLAY_POLICY = "reuse"
  REQUIRED_JWK_FIELDS = JitSecurityJwtJwk::REQUIRED_PUBLIC_FIELDS
  PRIVATE_JWK_FIELDS = JitSecurityJwtJwk::PRIVATE_FIELDS

  class << self
    def encode(payload, private_key:, kid:)
      JWT.encode(
        payload,
        private_key,
        ALGORITHM,
        { typ: TOKEN_TYPE, kid: kid },
      )
    end

    def build_issue_payload(issuer:, normalized_url:, dst:, ttl:, now:, jti:, audience:)
      issued_at = now.to_i
      {
        schema: SCHEMA,
        iss: issuer,
        aud: audience,
        sub: TOKEN_SUBJECT,
        iat: issued_at,
        nbf: issued_at,
        exp: issued_at + ttl.to_i,
        jti: jti,
        dst: dst,
        rpl: REPLAY_POLICY,
        url: normalized_url,
      }
    end

    def valid_header?(header)
      return false unless header["typ"] == TOKEN_TYPE
      return false unless header["alg"] == ALGORITHM
      return false if header["kid"].blank?
      return false if %w(crit jku jwk x5u).any? { |key| header.key?(key) }

      true
    end

    def decode_with_key(token:, key:, issuer:, audience:, leeway:)
      payload, = JWT.decode(
        token,
        key,
        true,
        algorithms: [ALGORITHM],
        required_claims: %w(schema iss aud sub iat nbf exp jti src dst rpl url),
        leeway: leeway,
        verify_iat: true,
        verify_exp: true,
        verify_iss: true,
        iss: issuer,
        verify_aud: true,
        aud: audience,
      )
      payload
    end

    def normalized_public_jwk(entry)
      JitSecurityJwtJwk.normalize_public(entry)
    rescue JitSecurityJwtJwk::Error
      nil
    end
  end
end
