# frozen_string_literal: true

require "test_helper"

class AuthAdmissionCsrfTransportTest < ActionDispatch::IntegrationTest
  %w(app com org).each do |surface|
    [
      ["same-origin header with a valid token", "same-origin", :valid, :local, 303],
      ["same-origin header without a token", "same-origin", :absent, :local, 422],
      ["same-origin header with an invalid token", "same-origin", :malformed, :local, 422],
      ["same-site header with a local Origin", "same-site", :valid, :local, 303],
      ["cross-site header despite a valid token", "cross-site", :valid, :local, 422],
      ["missing header with a valid form token", nil, :valid, :local, 303],
      ["missing header with a valid token header", nil, :header, :local, 303],
      ["missing header without a token", nil, :absent, :local, 422],
      ["missing header with a malformed token", nil, :malformed, :local, 422],
      ["none header with a valid token", "none", :valid, :local, 303],
      ["none header without a token", "none", :absent, :local, 422],
      ["same-origin header with a foreign Origin", "same-origin", :valid, :foreign, 422],
      ["same-origin header with a null Origin", "same-origin", :valid, :null, 422],
      ["missing Origin and header with a valid token", nil, :valid, :absent, 303],
    ].each do |description, fetch_site, token_kind, origin_kind, expected_status|
      test "#{surface} admission attachment respects standard CSRF for #{description}" do
        protection = ActionController::Base.allow_forgery_protection
        ActionController::Base.allow_forgery_protection = true
        host =
          case surface
          when "app" then ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          when "com" then ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
          when "org" then ENV.fetch("PUBLIC_AUTH_STAFF_URL")
          end
        issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface:, intent: "sign_in", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
        )
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
        browser = open_session
        browser.host!(host)
        browser.https!
        browser.get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" })
        csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        origin =
          case origin_kind
          when :local then "https://#{host}"
          when :foreign then "https://attacker.example"
          when :null then "null"
          when :absent then nil
          end
        headers = { "Origin" => origin, "Sec-Fetch-Site" => fetch_site }
        fields = { entry_ref: issuance.reference, ri: "jp" }
        fields[:authenticity_token] = csrf if token_kind == :valid
        fields[:authenticity_token] = "not-a-csrf-token" if token_kind == :malformed
        headers["X-CSRF-Token"] = csrf if token_kind == :header
        assert_difference -> { binding.class.auth_admission_session_class.count }, (expected_status == 303) ? 1 : 0 do
          browser.post("/ceremony_bindings", params: fields, headers:)
        end

        assert_equal expected_status, browser.response.status
        assert_equal expected_status == 303, binding.reload.attached?
        assert_nil binding.base_confirmed_at
        assert_nil binding.redeemed_at
        assert_nil binding.admitted_auth_ceremony_session_id
        assert_predicate issuance.transaction.reload, :sign_in_primary_pending?
        if binding.attached?
          auth_session = binding.class.auth_admission_session_class.find(binding.auth_ceremony_session_id)

          assert_predicate auth_session, :active?
          assert_not_predicate auth_session, :admitted?
        else
          assert_nil browser.response.location
          assert_nil browser.cookies["__Host-auth_sid"] || browser.cookies["auth_sid"]
        end
      ensure
        ActionController::Base.allow_forgery_protection = protection
      end
    end
  end
end
