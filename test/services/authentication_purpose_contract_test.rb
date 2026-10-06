# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationPurposeContractTest < ActiveSupport::TestCase
  test "ordinary sign in and sign up handoffs and results share neutral purposes" do
    assert_equal "authentication_handoff", issued_purpose_for(intent: "sign_in", kind: :handoff)
    assert_equal "authentication_handoff", issued_purpose_for(intent: "sign_up", kind: :handoff)
    assert_equal "authentication_result", issued_purpose_for(intent: "sign_in", kind: :result)
    assert_equal "authentication_result", issued_purpose_for(intent: "sign_up", kind: :result)
  end

  test "special-purpose handoffs and results remain distinct" do
    purposes = %w(invitation step_up reauthentication)

    handoffs = purposes.map { |intent| issued_purpose_for(intent:, kind: :handoff) }
    results = purposes.map { |intent| issued_purpose_for(intent:, kind: :result) }

    assert_equal %w(invitation_handoff step_up_handoff reauthentication_handoff), handoffs
    assert_equal %w(invitation_result step_up_result reauthentication_result), results
    assert_equal handoffs.length, handoffs.uniq.length
    assert_equal results.length, results.uniq.length
  end

  test "opaque store allows only the current purpose vocabulary" do
    assert_includes Valkey::AuthState::OpaqueAdmissionStore::PURPOSES, "authentication_handoff"
    assert_includes Valkey::AuthState::OpaqueAdmissionStore::PURPOSES, "authentication_result"
    assert_includes Valkey::AuthState::OpaqueAdmissionStore::PURPOSES, "invitation_handoff"
    assert_includes Valkey::AuthState::OpaqueAdmissionStore::PURPOSES, "reauthentication_result"
    assert_not_includes Valkey::AuthState::OpaqueAdmissionStore::PURPOSES, "sign_in_handoff"
    assert_not_includes Valkey::AuthState::OpaqueAdmissionStore::PURPOSES, "sign_up_result"
  end

  private

  def issued_purpose_for(intent:, kind:)
    store = PurposeCaptureStore.new
    client = OidcClientRegistry.find!("core-app")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: intent,
      params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "purpose-contract-challenge",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    transaction = OidcAuthorizationTransactionCoordinator.register_result!(
      surface: "app",
      login_challenge: transaction.login_challenge,
      actor: clients(:one),
      session_ref: nil,
      auth_method: "passkey",
      authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5),
    ).transaction

    if kind == :handoff
      BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction:, base_browser_nonce: "test-browser-nonce", base_token: nil, store:,
      )
    else
      BaseAuthAdmissionCoordinator.issue_result!(transaction:, store:)
    end

    store.purpose
  end

  class PurposeCaptureStore
    attr_reader :purpose

    def issue!(purpose:, **)
      @purpose = purpose
      "opaque-code"
    end
  end
end
