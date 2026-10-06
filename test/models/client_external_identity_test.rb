# frozen_string_literal: true

require "test_helper"

class ClientExternalIdentityTest < ActiveSupport::TestCase
  fixtures :client_statuses

  test "deterministically encrypts a provider subject while preserving subject lookup" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "e#{SecureRandom.hex(8)}")
    identity = ClientExternalIdentity.create!(
      client: client,
      provider: "apple",
      issuer: "https://appleid.apple.com",
      subject: "apple-subject-1",
      audience: "apple-client-id",
      verification_authority: "omniauth-apple/1.4.0",
      verified_at: Time.utc(2026, 7, 24, 12, 0, 0),
    )

    stored_value = ClientExternalIdentity.connection.select_value(
      ClientExternalIdentity.where(id: identity.id).select(:subject).to_sql,
    )

    assert_not_includes stored_value, "apple-subject-1"
    assert_equal identity, ClientExternalIdentity.find_by!(
      issuer: "https://appleid.apple.com",
      subject: "apple-subject-1",
    )
    assert_predicate identity, :active?
  end

  test "allows one effective external identity binding per client" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "e#{SecureRandom.hex(8)}")
    ClientExternalIdentity.create!(
      client: client,
      provider: "google",
      issuer: "https://accounts.google.com",
      subject: "google-subject-1",
      audience: "google-client-id",
      verification_authority: "omniauth-google-oauth2/1.2.1",
      verified_at: Time.current,
    )

    duplicate = ClientExternalIdentity.new(
      client: client,
      provider: "apple",
      issuer: "https://appleid.apple.com",
      subject: "apple-subject-2",
      audience: "apple-client-id",
      verification_authority: "omniauth-apple/1.4.0",
      verified_at: Time.current,
    )

    assert_predicate duplicate, :valid?
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save! }
  end

  test "touch_authenticated! records the latest sign-in without touching the binding" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "e#{SecureRandom.hex(8)}")
    identity = ClientExternalIdentity.create!(
      client: client,
      provider: "google",
      issuer: "https://accounts.google.com",
      subject: "google-subject-touch-#{SecureRandom.hex(4)}",
      audience: "google-client-id",
      verification_authority: "omniauth-google-oauth2/1.2.1",
      verified_at: Time.utc(2026, 7, 24, 12, 0, 0),
    )

    assert_nil identity.last_authenticated_at

    identity.touch_authenticated!

    assert_not_nil identity.reload.last_authenticated_at
    assert_equal Time.utc(2026, 7, 24, 12, 0, 0), identity.verified_at
  end
end
