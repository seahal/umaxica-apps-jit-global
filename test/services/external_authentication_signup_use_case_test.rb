# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"

class ExternalAuthenticationSignupUseCaseTest < ActiveSupport::TestCase
  include ExternalIdentityTestHelper

  test "creates an account and returns a typed signup result" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "signup-use-case-subject",
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )

    result = nil
    assert_difference("Client.count", 1) do
      assert_difference("ClientExternalIdentity.count", 1) do
        result = ExternalAuthenticationSignupUseCase.call(
          principal: principal,
          credential_candidate: nil,
          birthdate: "2000-01-01",
          ceremony_started_at: Time.current,
        )
      end
    end

    assert_instance_of ExternalAuthentication::SignupResult, result
    assert_equal :created, result.status
    assert_equal "signup-use-case-subject", result.identity.uid
    assert_equal result.user, result.identity.user
    assert ClientSocialAuditOutbox.exists?(
      owner_ref: result.user.public_id, identity_ref: result.identity.id.to_s, event_name: "linked",
    )
  end

  test "Source audit failure rolls back a social signup and its binding" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "apple", subject: SecureRandom.uuid, issuer: "https://appleid.apple.com",
      audience: "apple-client-id", verified_at: Time.current,
      verification_authority: "provider-fixture",
    )

    assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientSocialAuditOutbox.count"]) do
      ClientSocialAuditOutbox.stub(:create!, ->(*) { raise RuntimeError, "Source audit unavailable" }) do
        assert_raises(RuntimeError) do
          ExternalAuthenticationSignupUseCase.call(
            principal: principal, credential_candidate: nil, birthdate: "2000-01-01",
            ceremony_started_at: Time.current,
          )
        end
      end
    end
  end

  test "rejects a subject already bound to an account" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "signup_uc_#{SecureRandom.hex(4)}")
    identity = create_active_external_identity(client: client, provider: "google", subject: "signup-use-case-conflict")
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: identity.subject,
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )

    assert_raises(SocialAuth::ProviderError) do
      ExternalAuthenticationSignupUseCase.call(
        principal: principal,
        credential_candidate: nil,
        birthdate: "2000-01-01",
        ceremony_started_at: Time.current,
      )
    end
  end

  test "an app signup grant begun before account termination cannot recreate its social binding" do
    owner = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "signup_old_#{SecureRandom.hex(4)}")
    subject = SecureRandom.uuid
    identity = create_active_external_identity(client: owner, provider: "google", subject: subject)
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google", subject: subject, issuer: identity.issuer,
      audience: identity.audience, verified_at: Time.current,
      verification_authority: "provider-fixture",
    )
    stale_grant_at = Time.utc(2026, 1, 1)
    owner.update!(withdrawn_at: Time.current, terminated_at: Time.current)
    WithdrawalPersonalDataAnonymizer.call(actor: owner)

    assert_not ClientExternalIdentity.exists?(identity.id)
    assert_no_difference(["Client.count", "ClientExternalIdentity.count"]) do
      assert_raises(SocialAuth::ProviderError) do
        ExternalAuthenticationSignupUseCase.call(
          principal: principal, credential_candidate: nil, birthdate: "2000-01-01",
          ceremony_started_at: stale_grant_at,
        )
      end
    end
  end
end
