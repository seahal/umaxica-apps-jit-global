# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcAuthorizationTransactionPurgeJobTest < ActiveJob::TestCase
  test "uses the isolated retention queue" do
    assert_equal "retention", OidcAuthorizationTransactionPurgeJob.queue_name
  end

  test "removes an authorization transaction past its retention and keeps a live one" do
    client = OidcClientRegistry.find!("core-app")
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      nonce: "nonce",
      scope: "openid",
    }
    expired = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: params.merge(state: "expired"),
    ).transaction
    expired.update_columns(expires_at: 1.hour.ago)
    live = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: params.merge(state: "live"),
    ).transaction

    OidcAuthorizationTransactionPurgeJob.perform_now

    assert_not ClientOidcAuthorizationTransaction.exists?(expired.id)
    assert ClientOidcAuthorizationTransaction.exists?(live.id)
  end
end
