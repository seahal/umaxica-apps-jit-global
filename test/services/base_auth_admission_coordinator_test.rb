# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseAuthAdmissionCoordinatorTest < ActiveSupport::TestCase
  setup do
    skip "AUTH_STATE_REDIS_URL unset" if ENV["AUTH_STATE_REDIS_URL"].blank?
  end

  test "handoff consume is one-shot and bound to surface" do
    transaction = issue_transaction!

    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(transaction: transaction)
    payload = BaseAuthAdmissionCoordinator.consume_handoff!(
      raw_code: issuance.code,
      surface: "app",
      expected_intent: "sign_in",
    )

    assert_equal transaction.transaction_id, payload.fetch("subject_ref")
    assert_equal "app", payload.fetch("surface")
    assert_equal "client", payload.fetch("actor_type")

    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.consume_handoff!(
        raw_code: issuance.code,
        surface: "app",
        expected_intent: "sign_in",
      )
    end
  end

  test "result resume url uses Base authorize and omits raw login_challenge" do
    transaction = issue_transaction!
    OidcAuthorizationTransactionCoordinator.register_result!(
      surface: "app",
      login_challenge: transaction.login_challenge,
      actor: clients(:one),
      session_ref: "session-ref",
      auth_method: "passkey",
      authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5),
    )
    issuance = BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction.reload)

    uri = URI.parse(issuance.resume_url)
    query = Rack::Utils.parse_nested_query(uri.query)

    assert_equal "/oauth/authorize", uri.path
    assert_predicate query["result"], :present?
    assert_nil query["login_challenge"]
  end

  private

  def issue_transaction!
    OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_in",
      params: {
        response_type: "code",
        client_id: "core-app",
        redirect_uri: OidcClientRegistry.find!("core-app").redirect_uris.first,
        code_challenge: "challenge",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
  end
end
