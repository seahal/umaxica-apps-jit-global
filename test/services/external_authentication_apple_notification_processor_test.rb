# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationAppleNotificationProcessorTest < ActiveSupport::TestCase
  fixtures :client_statuses

  test "consent revocation disables the legacy Apple credential and every app session" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
    )
    identity = ClientAppleIdentity.create!(
      user: client,
      provider: "apple",
      uid: "notification-legacy-subject",
      token_expires_at: 0,
      status_id: ClientAppleIdentityStatus::ACTIVE,
    )
    event = ClientAppleNotificationEvent.create!(
      jti: "consent-#{SecureRandom.hex(8)}",
      event_type: "consent-revoked",
      client: client,
      client_external_identity: identity,
      received_at: Time.current,
      occurred_at: Time.current,
    )
    calls = []

    AuthenticationLogoutAllSessions.stub(:call, ->(**attributes) { calls << attributes }) do
      ExternalAuthenticationAppleNotificationProcessor.call(event: event)
    end

    assert_equal "completed", event.reload.status
    assert_equal ClientAppleIdentityStatus::REVOKED, identity.reload.status_id
    assert_not_respond_to identity, :refresh_token
    assert_equal [{ resource: client, reason: "apple_consent_revoked" }], calls
  end

  test "account deletion is terminal and cannot regress to consent revocation" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
    )
    identity = ClientAppleIdentity.create!(
      user: client,
      provider: "apple",
      uid: "notification-terminal-subject",
      token_expires_at: 0,
      status_id: ClientAppleIdentityStatus::ACTIVE,
    )
    deleted_event = ClientAppleNotificationEvent.create!(
      jti: "deleted-#{SecureRandom.hex(8)}",
      event_type: "account-deleted",
      client: client,
      client_external_identity: identity,
      received_at: Time.current,
      occurred_at: Time.current,
    )
    consent_event = ClientAppleNotificationEvent.create!(
      jti: "consent-#{SecureRandom.hex(8)}",
      event_type: "consent-revoked",
      client: client,
      client_external_identity: identity,
      received_at: Time.current,
      occurred_at: 1.minute.ago,
    )

    AuthenticationLogoutAllSessions.stub(:call, ->(**) { }) do
      ExternalAuthenticationAppleNotificationProcessor.call(event: deleted_event)
      ExternalAuthenticationAppleNotificationProcessor.call(event: consent_event)
    end

    assert_equal ClientAppleIdentityStatus::DELETED, identity.reload.status_id
    assert_equal "completed", deleted_event.reload.status
    assert_equal "completed", consent_event.reload.status
  end

  test "email forwarding events are acknowledged without changing the identity" do
    event = ClientAppleNotificationEvent.create!(
      jti: "email-#{SecureRandom.hex(8)}",
      event_type: "email-disabled",
      received_at: Time.current,
      occurred_at: Time.current,
    )

    ExternalAuthenticationAppleNotificationProcessor.call(event: event)

    assert_equal "completed", event.reload.status
  end

  test "does not apply an older account deletion after a newer consent revocation" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
    )
    identity = ClientAppleIdentity.create!(
      user: client,
      provider: "apple",
      uid: "notification-stale-subject",
      token_expires_at: 0,
      status_id: ClientAppleIdentityStatus::ACTIVE,
    )
    consent_event = ClientAppleNotificationEvent.create!(
      jti: "consent-newer-#{SecureRandom.hex(8)}",
      event_type: "consent-revoked",
      client: client,
      client_external_identity: identity,
      received_at: Time.current,
      occurred_at: Time.current,
    )
    deletion_event = ClientAppleNotificationEvent.create!(
      jti: "deleted-older-#{SecureRandom.hex(8)}",
      event_type: "account-deleted",
      client: client,
      client_external_identity: identity,
      received_at: Time.current,
      occurred_at: 1.minute.ago,
    )

    AuthenticationLogoutAllSessions.stub(:call, ->(**) { }) do
      ExternalAuthenticationAppleNotificationProcessor.call(event: consent_event)
      ExternalAuthenticationAppleNotificationProcessor.call(event: deletion_event)
    end

    assert_equal ClientAppleIdentityStatus::REVOKED, identity.reload.status_id
    assert_equal "completed", deletion_event.reload.status
  end
end
