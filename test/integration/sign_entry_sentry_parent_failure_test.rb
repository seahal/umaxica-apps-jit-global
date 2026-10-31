# typed: false
# frozen_string_literal: true

require "test_helper"

class SignEntrySentryParentFailureTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "an unavailable authorization parent refuses binding attachment on both auth surfaces" do
    [
      ["app", ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "core-app-jp", ClientAuthAdmissionBinding,
       ClientAuthCeremonySession, ClientOidcAuthorizationTransaction,],
      ["org", ENV.fetch("PUBLIC_AUTH_STAFF_URL"), "core-org-jp", OperatorAuthAdmissionBinding,
       OperatorAuthCeremonySession, OperatorOidcAuthorizationTransaction,],
    ].each do |surface, host, client_id, binding_class, session_class, transaction_class|
      client = OidcClientRegistry.find!(client_id)
      transaction = OidcAuthorizationTransactionCoordinator.issue!(
        surface: surface,
        intent: "sign_in",
        params: {
          response_type: "code",
          client_id: client_id,
          redirect_uri: client.redirect_uris_by_realm.fetch(client.resource_type).first,
          code_challenge: SecureRandom.urlsafe_base64(32),
          code_challenge_method: "S256",
          scope: "openid profile",
          state: SecureRandom.urlsafe_base64(24),
          nonce: SecureRandom.urlsafe_base64(24),
        },
      ).transaction
      issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
      )
      binding = binding_class.find_by!(entry_ref: issuance.reference)
      before = binding.attributes
      host! host
      https!

      [ActiveRecord::RecordNotFound, ArgumentError].each do |error_class|
        transaction_class.stub(:find, ->(*) { raise error_class }) do
          assert_no_difference -> { session_class.count } do
            get "/ceremony_bindings", params: { entry_ref: issuance.reference, ri: "jp" },
                                      headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }
          end
        end

        assert_response :bad_request
        assert_equal before, binding.reload.attributes
        assert_not_includes response.headers["Set-Cookie"].to_s, "auth_sid="
      end
    end
  end
end
