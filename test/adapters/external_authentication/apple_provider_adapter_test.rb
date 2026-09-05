# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationAppleProviderAdapterTest < ActiveSupport::TestCase
  test "translates strategy output into a minimal principal without retaining provider tokens" do
    auth_hash = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "verified-apple-subject",
      info: {
        email: "discarded@example.test",
        name: "Discarded Name",
      },
      credentials: {
        token: "discarded-access-token",
        refresh_token: "stored-refresh-token",
      },
      extra: {
        raw_info: {
          id_info: {
            sub: "forged-fallback-subject",
            email: "discarded@example.test",
          },
        },
      },
    )
    verified_at = Time.zone.local(2026, 7, 24, 12, 0, 0)
    adapter = ExternalAuthentication::AppleProviderAdapter.new(
      audience: "configured-apple-client-id",
    )

    result = adapter.call(auth_hash: auth_hash, verified_at: verified_at)

    assert_predicate result, :verified?
    assert_equal "apple", result.principal.provider
    assert_equal "verified-apple-subject", result.principal.subject
    assert_equal "https://appleid.apple.com", result.principal.issuer
    assert_equal "configured-apple-client-id", result.principal.audience
    assert_equal verified_at, result.principal.verified_at
    # The provenance field records which library verified the token, and the adapter reads the
    # version from the loaded gemspec. Deriving it the same way here keeps the contract asserted
    # -- name, separator, real loaded version -- without the assertion breaking on every omniauth-apple
    # bump, which is what a hard-coded literal here did.
    expected_authority = "omniauth-apple/#{Gem.loaded_specs.fetch("omniauth-apple").version}"

    assert_equal expected_authority, result.principal.verification_authority
    assert_match(%r{\Aomniauth-apple/\d+\.\d+\.\d+}, result.principal.verification_authority)
    assert_nil result.credential_candidate
    assert_equal(
      %i(provider subject issuer audience verified_at verification_authority tenant_context),
      result.principal.to_h.keys,
    )
  end

  test "rejects provider mismatch without reading nested claims" do
    auth_hash = OmniAuth::AuthHash.new(
      provider: "google",
      uid: "provider-subject",
      credentials: { refresh_token: "refresh-token" },
      extra: { raw_info: { id_info: { sub: "apple-subject" } } },
    )
    adapter = ExternalAuthentication::AppleProviderAdapter.new(
      audience: "configured-apple-client-id",
    )

    result = adapter.call(
      auth_hash: auth_hash,
      verified_at: Time.zone.local(2026, 7, 24, 12, 0, 0),
    )

    assert_predicate result, :failed?
    assert_equal :invalid_callback, result.failure.code
    assert_equal :provider_mismatch, result.failure.safe_reason
  end

  test "rejects missing top-level uid" do
    auth_hash = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: nil,
      credentials: { refresh_token: "refresh-token" },
      extra: { raw_info: { id_info: { sub: "forged-fallback-subject" } } },
    )
    adapter = ExternalAuthentication::AppleProviderAdapter.new(
      audience: "configured-apple-client-id",
    )

    result = adapter.call(
      auth_hash: auth_hash,
      verified_at: Time.zone.local(2026, 7, 24, 12, 0, 0),
    )

    assert_predicate result, :failed?
    assert_equal :assertion_invalid, result.failure.safe_reason
  end

  test "accepts a verified subject when the provider returns no refresh token" do
    auth_hash = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "verified-apple-subject",
      credentials: { token: "discarded-access-token" },
    )
    adapter = ExternalAuthentication::AppleProviderAdapter.new(
      audience: "configured-apple-client-id",
    )

    result = adapter.call(
      auth_hash: auth_hash,
      verified_at: Time.zone.local(2026, 7, 24, 12, 0, 0),
    )

    assert_predicate result, :verified?
    assert_equal "verified-apple-subject", result.principal.subject
    assert_nil result.credential_candidate
  end

  test "rejects an ordinary Hash that did not cross the OmniAuth boundary" do
    adapter = ExternalAuthentication::AppleProviderAdapter.new(
      audience: "configured-apple-client-id",
    )

    result = adapter.call(
      auth_hash: {
        "provider" => "apple",
        "uid" => "untrusted-subject",
        "credentials" => { "refresh_token" => "untrusted-refresh-token" },
      },
      verified_at: Time.zone.local(2026, 7, 24, 12, 0, 0),
    )

    assert_predicate result, :failed?
    assert_equal :callback_invalid, result.failure.safe_reason
  end
end
