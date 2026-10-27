# frozen_string_literal: true

require "test_helper"

class AcceptanceWu13AuthorizeUnrelatedParamsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "A13-4: cancellation and switch references are rejected before allocation" do
    observed = []

    [
      ["app", ENV.fetch("PUBLIC_VISA_SERVICE_URL"), "core-app-jp", "client",
       ClientOidcAuthorizationTransaction, ClientAuthAdmissionBinding,],
      ["com", ENV.fetch("PUBLIC_VISA_CORPORATE_URL"), "core-com-jp", "visitor",
       VisitorOidcAuthorizationTransaction, VisitorAuthAdmissionBinding,],
      ["org", ENV.fetch("PUBLIC_VISA_STAFF_URL"), "core-org-jp", "operator",
       OperatorOidcAuthorizationTransaction, OperatorAuthAdmissionBinding,],
    ].each do |surface, host, client_id, realm, transaction_class, binding_class|
      %i(cancellation_ref switch_handoff).each do |unrelated_parameter|
        host!(host)
        https!
        client = OidcClientRegistry.find!(client_id)
        state = SecureRandom.urlsafe_base64(24)
        params = {
          response_type: "code",
          client_id:,
          redirect_uri: client.redirect_uris_by_realm.fetch(realm).first,
          code_challenge: SecureRandom.urlsafe_base64(32, padding: false),
          code_challenge_method: "S256",
          scope: "openid profile",
          state:,
          nonce: SecureRandom.urlsafe_base64(24),
        }
        params[unrelated_parameter] = "unrelated-#{SecureRandom.uuid}"
        transactions_before = transaction_class.count
        bindings_before = binding_class.count

        get "/oauth/authorize", params: params, headers: {
          "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
        }

        transaction = transaction_class.find_by(state: state)
        observed << [
          surface, unrelated_parameter, response.status,
          transaction_class.count - transactions_before,
          binding_class.count - bindings_before,
          transaction && [transaction.status, transaction.intent,
                          transaction.cancellation_handoff_ref, transaction.cancellation_handoff_ciphertext,],
        ]
      end
    end

    expected =
      %w(app com org).flat_map do |surface|
        %i(cancellation_ref switch_handoff).map do |parameter|
          [surface, parameter, 400, 0, 0, nil]
        end
      end

    assert_equal expected, observed
  end
end
