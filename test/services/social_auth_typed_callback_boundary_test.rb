# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"

class SocialAuthTypedCallbackBoundaryTest < ActiveSupport::TestCase
  include ExternalIdentityTestHelper

  test "login use case resolves an existing Google identity from a verified principal without provider payload" do
    client = Client.create!(
      status_id: ClientStatus::ACTIVE,
      public_id: "typed_google_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    identity = create_active_external_identity(client: client, provider: "google", subject: "typed-google-subject")
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: identity.subject,
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )

    result = ExternalAuthenticationLoginUseCase.call(
      principal: principal,
      credential_candidate: nil,
      sign_up_entry: false,
      ceremony_started_at: Time.current,
    )

    assert_equal client, result.user
    assert_equal identity, result.identity
  end

  test "callback credentials never cross the verified-principal boundary" do
    auth_hash = OmniAuth::AuthHash.new(
      provider: "google",
      uid: "untrusted-subject",
      credentials: { token: "must-not-cross-boundary" },
    )

    result = ExternalAuthentication::CallbackResult.verified(
      principal: ExternalAuthentication::VerifiedPrincipal.new(
        provider: "google",
        subject: auth_hash.uid,
        issuer: "https://accounts.google.com",
        audience: "client-id",
        verified_at: Time.current,
        verification_authority: "contract",
      ),
    )

    assert_nil result.credential_candidate
    assert_not_includes result.principal.to_h.values, "must-not-cross-boundary"
  end
end
