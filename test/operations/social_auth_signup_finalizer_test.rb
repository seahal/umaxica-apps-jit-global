# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/sign-up-finalization-in-auth.md F3: the pending Client from the confirmation receives its
# External Identity and its registered status in one principal transaction.
class SocialAuthSignupFinalizerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "rejects a signup callback without a verified external principal" do
    error =
      assert_raises(SocialAuth::ProviderError) do
        SocialAuthSignupFinalizer.call(
          user: pending_client, principal: Object.new, credential_candidate: nil,
          ceremony_started_at: Time.current, flow: nil,
        )
      end

    assert_equal "errors.social_auth.provider_error", error.i18n_key
  end

  test "links the identity to the pending Client and registers it" do
    client = pending_client
    identity = finalize(client, subject: "finalizer-#{SecureRandom.hex(4)}").fetch(:identity)

    assert_equal client.id, identity.client_id
    assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, client.reload.status_id
  end

  test "refuses a subject already linked to another Client and leaves the pending Client unfinished" do
    subject = "finalizer-taken-#{SecureRandom.hex(4)}"
    finalize(pending_client, subject: subject)
    second = pending_client

    assert_raises(SocialAuth::ProviderError) { finalize(second, subject: subject) }
    assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, second.reload.status_id
    assert_not ClientExternalIdentity.exists?(client_id: second.id)
  end

  test "refuses a Client that is not pending and writes no identity" do
    client = pending_client
    client.update!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)

    assert_raises(FlowInvalidTransition) { finalize(client, subject: "finalizer-#{SecureRandom.hex(4)}") }
    assert_not ClientExternalIdentity.exists?(client_id: client.id)
  end

  private

  def pending_client
    Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP, security_mode_id: SecurityModeConfigurable::NORMAL)
  end

  def finalize(client, subject:)
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google", subject: subject, issuer: "https://accounts.google.com", audience: "client-id",
      verified_at: Time.current, verification_authority: "omniauth-google/1.0.0",
    )
    flow = social_flow(client, principal)
    SocialAuthSignupFinalizer.call(
      user: client, flow: flow, principal: principal, credential_candidate: nil, ceremony_started_at: flow.issued_at,
    )
  end

  def social_flow(client, principal)
    now = ClientSignUpFlow.database_now
    ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: client.id, entry_method: principal.provider, social_provider: principal.provider,
      pending_contact_type: "social_identity", status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint", issued_at: now, expires_at: now + 15.minutes,
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.hex(16)),
      completed_requirements: {
        "confirmation" => { "cleared" => true },
        "birthdate" => { "cleared" => true },
        "social_signup" => { "provider" => principal.provider,
                             "uid_digest" => OpenSSL::HMAC.hexdigest(
                               "SHA256", Rails.application.secret_key_base,
                               [principal.provider, principal.subject].join(":"),
                             ), },
      },
    )
  end
end
