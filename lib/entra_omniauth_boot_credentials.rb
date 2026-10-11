# typed: false
# frozen_string_literal: true

# Resolves and shape-validates the three Entra credentials OmniAuth needs to
# register the org provider at boot.
#
# Non-local deployments fail closed at boot on any missing or malformed value:
# a tenant id or client id that only surfaces on the first staff sign-in turns a
# configuration mistake into an authentication outage discovered by a user.
# Development and test return nil when the set is absent so processes that never
# exercise Entra/OIDC (CMS and other non-Entra suites) can boot without an IdP
# credential; the org Entra preflight and ProviderRegistry still raise when the
# provider is actually used.
#
# Shape only: presence plus UUID format for the two identifiers. No semantic
# validation (issuer metadata, tenant reachability) happens here, because boot
# must not depend on reaching Microsoft. That remains in OrgEntraSignInPreflight.
#
# No credential value ever appears in an error message.
module EntraOmniauthBootCredentials
  Credentials = Data.define(:tenant_id, :client_id, :client_secret)

  TENANT_ID_NAME = "OMNI_AUTH_ENTRA_ORG_TENANT_ID"
  CLIENT_ID_NAME = "OMNI_AUTH_ENTRA_ORG_CLIENT_ID"
  CLIENT_CREDENTIAL_NAME = "OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET"

  UUID_PATTERN = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

  module_function

  # Returns a Credentials value, or nil in development/test when none of the
  # three are configured. Raises KeyError otherwise.
  def resolve_for_boot(tenant_id:, client_id:, client_secret:, env: Rails.env)
    values = {
      TENANT_ID_NAME => tenant_id.to_s,
      CLIENT_ID_NAME => client_id.to_s,
      CLIENT_CREDENTIAL_NAME => client_secret.to_s,
    }

    return nil if local_boot_without_entra?(values, env: env)

    values.each_key { |key| require_present!(values, key) }
    require_uuid!(values, TENANT_ID_NAME)
    require_uuid!(values, CLIENT_ID_NAME)

    Credentials.new(
      tenant_id: values.fetch(TENANT_ID_NAME),
      client_id: values.fetch(CLIENT_ID_NAME),
      client_secret: values.fetch(CLIENT_CREDENTIAL_NAME),
    )
  end

  # A local environment with no Entra credentials at all omits the provider.
  # A partially configured local environment still fails, so a typo in one of
  # three values is reported at boot instead of silently disabling staff login.
  def local_boot_without_entra?(values, env:)
    return false unless env.development? || env.test?

    values.each_value.all?(&:blank?)
  end

  def require_present!(values, key)
    return if values.fetch(key).present?

    raise KeyError, "#{key} is required for Microsoft Entra ID authentication"
  end

  def require_uuid!(values, key)
    return if values.fetch(key).match?(UUID_PATTERN)

    raise KeyError, "#{key} must be a valid UUID"
  end
end
