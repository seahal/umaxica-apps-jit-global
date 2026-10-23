# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationLinkUseCaseTest < ActiveSupport::TestCase
  fixtures

  test "links a verified principal and returns a typed result" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
    )
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "link-use-case-subject",
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )

    result = ExternalAuthenticationLinkUseCase.call(
      principal: principal,
      credential_candidate: nil,
      user: client,
      ceremony_started_at: Time.current,
    )

    assert_instance_of ExternalAuthentication::LinkResult, result
    assert_equal :linked, result.status
    assert_equal client, result.user
    assert_equal "link-use-case-subject", result.identity.uid
    assert_equal client, result.identity.user
  end

  test "rejects link without an authenticated user" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "link-use-case-no-user",
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )

    assert_raises(SocialAuth::UnauthorizedError) do
      ExternalAuthenticationLinkUseCase.call(
        principal: principal,
        credential_candidate: nil,
        user: nil,
        ceremony_started_at: Time.current,
      )
    end
  end

  test "a pre-release grant cannot reattach another client but a new grant can" do
    original = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
    )
    challenger = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
    )
    subject = SecureRandom.uuid
    identity = ClientExternalIdentity.create!(
      client: original, provider: "google", issuer: "https://accounts.google.com",
      subject: subject, audience: "google-client-id", verification_authority: "provider-fixture",
      verified_at: ClientExternalIdentity.database_now,
    )
    original.client_emails.create!(
      address: "social-release-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    ).finalize_binding!
    old_grant_at = Time.utc(2026, 1, 1)

    assert_equal :unlinked, ExternalAuthenticationUnlinkUseCase.call(provider: "google", user: original).status
    assert_operator identity.reload.released_at, :>, old_grant_at

    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google", subject: subject, issuer: "https://accounts.google.com",
      audience: "google-client-id", verified_at: Time.current,
      verification_authority: "provider-fixture",
    )
    assert_no_difference -> { ClientSocialAuditOutbox.where(owner_ref: challenger.public_id).count } do
      assert_raises(SocialAuth::ConflictError) do
        ExternalAuthenticationLinkUseCase.call(
          principal: principal, credential_candidate: nil, user: challenger,
          ceremony_started_at: old_grant_at,
        )
      end
    end
    assert_not ClientExternalIdentity.effective_binding.exists?(client_id: challenger.id)

    new_grant_at = Time.current

    assert_operator new_grant_at, :>, identity.released_at
    result = ExternalAuthenticationLinkUseCase.call(
      principal: principal, credential_candidate: nil, user: challenger,
      ceremony_started_at: new_grant_at,
    )

    assert_equal :linked, result.status
    assert_equal challenger.id, result.identity.client_id
    assert_not_equal identity.id, result.identity.id
  end

  test "a grant issued before app account termination cannot reattach its deleted social subject" do
    original = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
    )
    challenger = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
    )
    subject = SecureRandom.uuid
    identity = ClientExternalIdentity.create!(
      client: original, provider: "apple", issuer: "https://appleid.apple.com",
      subject: subject, audience: "apple-client-id", verification_authority: "provider-fixture",
      verified_at: ClientExternalIdentity.database_now,
    )
    stale_grant_at = Time.utc(2026, 1, 1)
    original.update!(withdrawn_at: Time.current, terminated_at: Time.current)

    WithdrawalPersonalDataAnonymizer.call(actor: original)

    assert_not ClientExternalIdentity.exists?(identity.id)
    event = ClientSocialAuditOutbox.find_by!(
      owner_ref: original.public_id, identity_ref: identity.id.to_s, event_name: "unlinked",
    )
    assert_difference -> { ClientChronicle.where(event_uuid: event.event_uuid).count }, 1 do
      SocialAuditDeliveryJob.perform_now
    end
    assert_not_nil event.reload.acknowledged_at
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "apple", subject: subject, issuer: "https://appleid.apple.com",
      audience: "apple-client-id", verified_at: Time.current,
      verification_authority: "provider-fixture",
    )

    assert_raises(SocialAuth::ConflictError) do
      ExternalAuthenticationLinkUseCase.call(
        principal: principal, credential_candidate: nil, user: challenger,
        ceremony_started_at: stale_grant_at,
      )
    end
    assert_not ClientExternalIdentity.effective_binding.exists?(client_id: challenger.id)
  end
end
