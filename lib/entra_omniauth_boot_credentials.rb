# typed: false
# frozen_string_literal: true

# Resolves the Entra client secret for OmniAuth registration at boot.
#
# Production still fails closed when the secret is missing. Development and
# test return nil so processes that never exercise Entra/OIDC can boot without
# an IdP credential. The org Entra preflight and the token exchange still
# require a real secret when the entra provider is used.
module EntraOmniauthBootCredentials
  module_function

  def secret_for_boot(raw_secret, env: Rails.env)
    secret = raw_secret.to_s
    return secret if secret.present?
    return nil unless env.production?

    raise KeyError, "credential OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET is required for the entra provider"
  end
end
