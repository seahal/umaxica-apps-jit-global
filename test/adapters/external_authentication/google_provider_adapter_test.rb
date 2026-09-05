# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationGoogleProviderAdapterTest < ActiveSupport::TestCase
  test "translates the strategy-verified ID token subject into a minimal principal" do
    auth_hash = OmniAuth::AuthHash.new(
      provider: "google",
      uid: "verified-id-token-subject",
      info: {
        email: "discarded@example.test",
        name: "Discarded Name",
        image: "https://example.test/discarded.png",
      },
      credentials: {
        token: "discarded-access-token",
        refresh_token: "discarded-refresh-token",
      },
      extra: {
        id_info: {
          sub: "verified-id-token-subject",
        },
        raw_info: {
          sub: "discarded-userinfo-subject",
          email: "discarded@example.test",
        },
      },
    )
    verified_at = Time.zone.local(2026, 7, 24, 12, 0, 0)
    adapter = ExternalAuthentication::GoogleProviderAdapter.new(
      audience: "configured-google-client-id",
    )

    result = adapter.call(auth_hash: auth_hash, verified_at: verified_at)

    assert_predicate result, :verified?
    assert_equal "google", result.principal.provider
    assert_equal "verified-id-token-subject", result.principal.subject
    assert_equal "https://accounts.google.com", result.principal.issuer
    assert_equal "configured-google-client-id", result.principal.audience
    assert_equal verified_at, result.principal.verified_at
    # The provenance field records which library verified the token, and the adapter reads the
    # version from the loaded gemspec. Deriving it the same way here keeps the contract asserted
    # -- name, separator, real loaded version -- without the assertion breaking on every omniauth-google-oauth2
    # bump, which is what a hard-coded literal here did.
    expected_authority = "omniauth-google-oauth2/#{Gem.loaded_specs.fetch("omniauth-google-oauth2").version}"

    assert_equal expected_authority, result.principal.verification_authority
    assert_match(%r{\Aomniauth-google-oauth2/\d+\.\d+\.\d+}, result.principal.verification_authority)
    assert_nil result.credential_candidate
    assert_equal(
      %i(provider subject issuer audience verified_at verification_authority tenant_context),
      result.principal.to_h.keys,
    )
  end

  test "rejects provider mismatch" do
    auth_hash = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "provider-subject",
      extra: { raw_info: { sub: "provider-subject" } },
    )
    adapter = ExternalAuthentication::GoogleProviderAdapter.new(
      audience: "configured-google-client-id",
    )

    result = adapter.call(
      auth_hash: auth_hash,
      verified_at: Time.zone.local(2026, 7, 24, 12, 0, 0),
    )

    assert_predicate result, :failed?
    assert_equal :provider_mismatch, result.failure.safe_reason
  end

  test "rejects missing top-level uid instead of falling back to raw provider data" do
    auth_hash = OmniAuth::AuthHash.new(
      provider: "google",
      uid: nil,
      extra: {
        id_info: { sub: "forged-id-info-subject" },
        raw_info: { sub: "forged-raw-info-subject" },
      },
    )
    adapter = ExternalAuthentication::GoogleProviderAdapter.new(
      audience: "configured-google-client-id",
    )

    result = adapter.call(
      auth_hash: auth_hash,
      verified_at: Time.zone.local(2026, 7, 24, 12, 0, 0),
    )

    assert_predicate result, :failed?
    assert_equal :assertion_invalid, result.failure.safe_reason
  end

  test "rejects an ordinary Hash that did not cross the OmniAuth boundary" do
    adapter = ExternalAuthentication::GoogleProviderAdapter.new(
      audience: "configured-google-client-id",
    )

    result = adapter.call(
      auth_hash: {
        "provider" => "google",
        "uid" => "untrusted-subject",
      },
      verified_at: Time.zone.local(2026, 7, 24, 12, 0, 0),
    )

    assert_predicate result, :failed?
    assert_equal :callback_invalid, result.failure.safe_reason
  end
end
