# typed: false
# frozen_string_literal: true

module OidcDiscoveryDocument
  module_function

  def for_resource_type(resource_type)
    issuer = OidcIssuer.for_resource_type(resource_type)

    {
      issuer: issuer,
      authorization_endpoint: OidcIssuer.authorization_endpoint(resource_type),
      token_endpoint: OidcIssuer.token_endpoint(resource_type),
      userinfo_endpoint: OidcIssuer.userinfo_endpoint(resource_type),
      jwks_uri: OidcIssuer.jwks_uri(resource_type),
      revocation_endpoint: OidcIssuer.revocation_endpoint(resource_type),
      end_session_endpoint: OidcIssuer.end_session_endpoint(resource_type),
      backchannel_logout_supported: true,
      backchannel_logout_session_supported: true,
      response_types_supported: ["code"],
      # RFC 9207. The authorization response carries `iss`; advertising it lets a
      # conforming client require the parameter and reject a response that omits it.
      authorization_response_iss_parameter_supported: true,
      grant_types_supported: %w(authorization_code refresh_token),
      subject_types_supported: ["public"],
      id_token_signing_alg_values_supported: [AuthenticationTokenService::JWT_ALGORITHM],
      token_endpoint_auth_signing_alg_values_supported: [AuthenticationTokenService::JWT_ALGORITHM],
      token_endpoint_auth_methods_supported: %w(private_key_jwt client_secret_post none),
      code_challenge_methods_supported: ["S256"],
      scopes_supported: %w(openid profile email),
      claims_supported: %w(sub iss aud exp iat auth_time nonce acr amr sid email email_verified name),
    }
  end
end
