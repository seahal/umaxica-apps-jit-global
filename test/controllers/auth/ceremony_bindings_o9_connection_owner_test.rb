# frozen_string_literal: true

require "test_helper"

class AuthCeremonyBindingsO9ConnectionOwnerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  test "ordinary APP and ORG binding requests work without O-9 admission metadata" do
    [
      ["app", "PUBLIC_AUTH_SERVICE_URL", ClientAuthAdmissionBinding],
      ["org", "PUBLIC_AUTH_STAFF_URL", OperatorAuthAdmissionBinding],
    ].each do |surface, auth_host_env, binding_model|
      issuance = OidcTestEntry.issue!(
        surface:, intent: "sign_in", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
      )
      binding = binding_model.find_by!(entry_ref: issuance.reference)
      browser = open_session
      browser.https!
      browser.host!(ENV.fetch(auth_host_env))
      browser.get(
        "/ceremony_bindings",
        params: { entry_ref: issuance.reference, ri: "jp" },
        headers: NAVIGATION_HEADERS,
      )

      assert_equal 303, browser.response.status, surface
      assert_predicate binding.reload, :attached?, surface
      assert_match %r{/ceremony_bindings/.+/confirmation}, URI.parse(browser.response.location).path, surface
    end
  end
end
