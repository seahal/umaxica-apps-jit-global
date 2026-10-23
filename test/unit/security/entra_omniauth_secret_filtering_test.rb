# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  # Confirms that every parameter an OIDC token exchange can carry is filtered
  # from Rails request/parameter logging. Entra authenticates with a client
  # secret (adr/org-entra-single-tenant-credential-configuration.md); the
  # client_assertion and key/certificate parameters stay covered because the
  # production credential mechanism is not final and other providers may use
  # them. See lib/omniauth/strategies/umaxica_entra.rb.
  class EntraOmniauthSecretFilteringTest < ActiveSupport::TestCase
    test "filters OIDC/OmniAuth transport secrets from logged parameters" do
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      filtered = filter.filter(
        "code" => "authorization-code",
        "id_token" => "header.payload.signature",
        "access_token" => "access-token-value",
        "refresh_token" => "refresh-token-value",
        "client_assertion" => "header.payload.signature",
        "client_assertion_type" => "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
        "client_secret" => "client-secret-value",
        "code_verifier" => "pkce-verifier",
        "code_challenge" => "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        "nonce" => "nonce-value",
        "state" => "state-value",
        "private_key_pem" => "-----BEGIN PRIVATE KEY-----",
        "certificate_pem" => "-----BEGIN CERTIFICATE-----",
      )

      %w(
        code id_token access_token refresh_token client_assertion client_secret
        code_verifier nonce state private_key_pem certificate_pem
      ).each do |key|
        assert_equal "[FILTERED]", filtered.fetch(key), "expected #{key} to be filtered"
      end
    end
  end
end
