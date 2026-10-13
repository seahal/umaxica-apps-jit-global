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
      return false unless header.is_a?(Hash)
      return false unless header.keys.sort == %w(alg kid typ)
      return false unless header["typ"] == TOKEN_TYPE
      return false unless header["alg"] == ALGORITHM
      return false unless valid_kid?(header["kid"])

      true
    end

    def valid_kid?(value)
      return false unless value.is_a?(String) && value.present?
      return false if value.codepoints.any? { |codepoint| codepoint < 0x20 || (0x7f..0x9f).cover?(codepoint) }

      value.encode(Encoding::UTF_16LE).bytesize / 2 <= 128
    rescue EncodingError
      false
    end

    def decode_with_key(token:, key:, issuer:, audience:, leeway:)
      payload, = JWT.decode(
        token,
        key,
        true,
        algorithms: [ALGORITHM],
        required_claims: %w(schema iss aud sub iat nbf exp jti src dst rpl url),
        leeway: leeway,
        # jwt applies `leeway` to exp and nbf only; iat needs its own leeway option.
        verify_iat: { leeway: leeway },
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
