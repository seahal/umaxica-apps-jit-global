# typed: false
# frozen_string_literal: true

# Shared RFC 9068 access-token header and claim-type policy for first-party
# auth_access and preference_access tokens (and OIDC access tokens that share
# the auth codec).
#
# UMAXICA follows RFC 9068 token structure, claims, semantics, and validation
# with one documented interoperability deviation: ES384 is the only supported
# signing algorithm, and RS256 is intentionally not implemented.
module SecurityJwtRfc9068AccessTokenProfile
  ALGORITHM = "ES384"
  TOKEN_TYPE = "at+jwt"
  REQUIRED_CLAIMS = %w(iss exp aud sub client_id iat jti).freeze
  RESOURCE_TYPE_SCOPE_PREFIX = "domain:"
  # Claims that earlier private token formats carried and that this profile
  # must never accept again: `scp` (replaced by `scope`), payload `typ`
  # (replaced by the JOSE header), and `act` (RFC 8693 actor semantics).
  FORBIDDEN_CLAIMS = %w(scp typ act).freeze
  # Fixed clock-skew allowance for exp/nbf/iat. A constant rather than an
  # environment knob so no deployment can widen token validity by omission.
  CLOCK_SKEW_LEEWAY_SECONDS = 30
  # Identifiers that only make sense outside production: loopback hosts, the
  # reserved `.test` TLD, and development/test issuer or audience names.
  NON_PRODUCTION_IDENTIFIER_PATTERN =
    /localhost|127\.0\.0\.1|::1|\.test\z|\b(?:development|test)\b/i

  module_function

  def header_valid?(header)
    return false unless header.is_a?(Hash)
    return false unless header["alg"] == ALGORITHM
    return false unless header["typ"] == TOKEN_TYPE
    return false if header["kid"].blank?

    true
  end

  def header_rejection_reason(header)
    return "MALFORMED_TOKEN" if header.blank? || !header.is_a?(Hash) || header["alg"].blank?
    return "MISSING_KID" if header["kid"].blank?
    return "ALG_NONE" if header["alg"] == "none"
    return "ALG_MISMATCH" if header["alg"] != ALGORITHM
    return "MISSING_TYP" if header["typ"].blank?
    return "TYP_MISMATCH" if header["typ"] != TOKEN_TYPE

    "INVALID_HEADER"
  end

  def claims_structurally_valid?(payload)
    return false unless payload.is_a?(Hash)
    return false unless REQUIRED_CLAIMS.all? { |claim| payload.key?(claim) }
    return false unless required_string_claims_present?(payload)
    return false unless integer_time?(payload["iat"])
    return false unless integer_time?(payload["exp"])
    return false unless audience_valid?(payload["aud"])
    return false unless scope_valid?(payload["scope"])
    return false if payload.key?("nbf") && !integer_time?(payload["nbf"])
    return false if FORBIDDEN_CLAIMS.any? { |claim| payload.key?(claim) }

    true
  end

  # Raises when a production process is configured with an identifier that
  # belongs to development or test, so another environment's tokens can never
  # verify there.
  def assert_production_identifiers!(values, label:, production: Rails.env.production?)
    return unless production

    forbidden = Array(values).select { |value| NON_PRODUCTION_IDENTIFIER_PATTERN.match?(value.to_s) }
    return if forbidden.empty?

    raise ArgumentError, "#{label} must not include non-production identifiers: #{forbidden.join(", ")}"
  end

  def parse_scopes(payload)
    return [] unless payload.is_a?(Hash)

    case payload["scope"]
    when String
      payload["scope"].split
    else
      []
    end
  end

  def resource_type_from_scope(payload)
    types =
      parse_scopes(payload).filter_map do |scope|
        next unless scope.start_with?(RESOURCE_TYPE_SCOPE_PREFIX)

        scope.delete_prefix(RESOURCE_TYPE_SCOPE_PREFIX).presence
      end
    types.uniq!
    types.one? ? types.first : nil
  end

  def required_string_claims_present?(payload)
    %w(sub client_id iss jti).all? { |claim| payload[claim].is_a?(String) && payload[claim].present? }
  end
  private_class_method :required_string_claims_present?

  def integer_time?(value)
    value.is_a?(Integer)
  end
  private_class_method :integer_time?

  def audience_valid?(aud)
    case aud
    when String then aud.present?
    when Array then aud.any? && aud.all? { |value| value.is_a?(String) && value.present? }
    else false
    end
  end
  private_class_method :audience_valid?

  # Both token families authorize through `scope`, so it is required and must
  # be the RFC 8693 space-delimited string, never an array.
  def scope_valid?(scope)
    scope.is_a?(String) && scope.strip.present?
  end
  private_class_method :scope_valid?
end
