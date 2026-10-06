# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcRefreshDeliveryReceiptTest < ActiveSupport::TestCase
  test "receipt encryption preserves bindings and the complete token response" do
    now = Time.utc(2026, 10, 6, 1, 0, 0)
    response = {
      access_token: "access",
      token_type: "Bearer",
      expires_in: 300,
      refresh_token: "refresh",
      refresh_token_expires_in: 3600,
      id_token: "id",
    }
    ciphertext = OidcRefreshDeliveryReceipt.encrypt(
      rp_session_public_id: "rp-1",
      client_id: "base-app-ww",
      resource_type: "client",
      predecessor_digest: "a" * 96,
      generation: 1,
      expires_at: now + 5.seconds,
      access_expires_at: now + 5.minutes,
      refresh_expires_at: now + 1.hour,
      token_response: response,
    )

    receipt = OidcRefreshDeliveryReceipt.decrypt(ciphertext)

    assert receipt.matches?(
      rp_session_public_id: "rp-1",
      client_id: "base-app-ww",
      resource_type: "client",
      predecessor_digest: "a" * 96,
      generation: 1,
    )
    assert_equal response, receipt.token_response
    assert_equal 300, receipt.token_response_for(now: now).fetch(:expires_in)
    assert_equal 3600, receipt.token_response_for(now: now + 1.second).fetch(:refresh_token_expires_in)
    assert_equal 3599, receipt.remaining_expiries(now: now + 1.second).fetch(:refresh_remaining_seconds)
  end

  test "receipt tampering and reversed absolute deadlines fail closed" do
    assert_raises(OidcRefreshDeliveryReceipt::Invalid) do
      OidcRefreshDeliveryReceipt.decrypt("not-a-receipt")
    end

    assert_raises(OidcRefreshDeliveryReceipt::Invalid) do
      OidcRefreshDeliveryReceipt.encrypt(
        rp_session_public_id: "rp-1",
        client_id: "base-app-ww",
        resource_type: "client",
        predecessor_digest: "a" * 96,
        generation: 1,
        expires_at: 5.seconds.from_now,
        access_expires_at: 5.minutes.from_now,
        refresh_expires_at: 1.minute.from_now,
        token_response: { expires_in: 300, refresh_token_expires_in: 60 },
      )
    end
  end
end
