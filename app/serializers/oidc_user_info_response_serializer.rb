# typed: false
# frozen_string_literal: true

module OidcUserInfoResponseSerializer
  module_function

  def build(resource:, payload:)
    resource_type =
      AuthorizationTokenClaims.resource_type(payload).presence ||
      SecurityJwtOidcIdTokenCodec.resource_type_for_resource(resource)
    scopes = AuthorizationTokenClaims.scopes(payload)
    claims = {
      sub: OidcSubject.for(resource, resource_type: resource_type),
      acr: payload["acr"],
      amr: payload["amr"],
      auth_time: payload["auth_time"],
    }.compact

    attach_profile_claims(claims, resource, scopes: scopes)
    claims
  end

  def attach_profile_claims(claims, resource, scopes:)
    claims[:name] = resource.name if scopes.include?("profile") && resource.respond_to?(:name) && resource.name.present?
    return unless scopes.include?("email")

    claims[:email] = resource.email if resource.respond_to?(:email) && resource.email.present?
    claims[:email_verified] = true if claims[:email].present?
  end
  private_class_method :attach_profile_claims
end
