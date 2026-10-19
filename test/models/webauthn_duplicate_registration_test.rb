# typed: false
# frozen_string_literal: true

require "test_helper"

# Duplicate-registration guarantees at the data layer: the credential ID
# (webauthn_id) is unique per surface regardless of owner, while AAGUID and
# provider metadata never participate in duplicate detection (an AAGUID names
# a product line, not an authenticator instance).
class WebauthnDuplicateRegistrationTest < ActiveSupport::TestCase
  def build_client_passkey(**attrs)
    ClientPasskey.new(
      user: clients(:one),
      webauthn_id: Base64.urlsafe_encode64(SecureRandom.random_bytes(16), padding: false),
      public_key: "public_key",
      description: "test key",
      sign_count: 0,
      **attrs,
    )
  end

  test "the same credential id cannot be registered twice for the same account" do
    existing = build_client_passkey
    existing.save!

    duplicate = build_client_passkey(webauthn_id: existing.webauthn_id)

    assert_not duplicate.valid?
    assert_predicate duplicate.errors[:webauthn_id], :any?
  end

  test "the same credential id cannot be registered for a different account on the same surface" do
    existing = build_client_passkey
    existing.save!

    duplicate = build_client_passkey(user: clients(:placeholder), webauthn_id: existing.webauthn_id)

    assert_not duplicate.valid?
  end

  test "a duplicate insert that bypasses validation is stopped by the database unique index" do
    existing = build_client_passkey
    existing.save!

    duplicate = build_client_passkey(
      user: clients(:placeholder), webauthn_id: existing.webauthn_id, external_id: SecureRandom.uuid,
    )

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "a revoked credential's id still blocks re-registration" do
    existing = build_client_passkey(status_id: ClientPasskeyStatus::REVOKED)
    existing.save!

    duplicate = build_client_passkey(webauthn_id: existing.webauthn_id)

    assert_not duplicate.valid?
  end

  test "two credentials sharing an AAGUID and provider name are both registrable" do
    aaguid = SecureRandom.uuid
    first = build_client_passkey(aaguid: aaguid, provider_name: "Google Titan Security Key")
    first.save!

    second = build_client_passkey(
      aaguid: aaguid, provider_name: "Google Titan Security Key",
    )

    assert second.save
  end

  test "actors receive an opaque unique webauthn user handle on create" do
    client = clients(:one)

    assert_predicate client.webauthn_user_handle, :present?
    assert_not_equal client.id.to_s, client.webauthn_user_handle

    fresh = Client.new
    fresh.valid?

    assert_predicate fresh.webauthn_user_handle, :present?
    assert_not_equal client.webauthn_user_handle, fresh.webauthn_user_handle
  end
end
