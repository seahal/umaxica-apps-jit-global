# frozen_string_literal: true

require "test_helper"

class AdmissionRedemptionInputBoundaryTest < ActionDispatch::IntegrationTest
  %w(app com org).each do |surface|
    %w(missing_cookie foreign_cookie unconfirmed unattached).each do |attack|
      test "#{surface} redemption refuses #{attack} then resumes only its retained confirmed binding" do
        protection = ActionController::Base.allow_forgery_protection
        ActionController::Base.allow_forgery_protection = true
        host = auth_host_for_test(surface)
        issuance = OidcTestEntry.issue!(
          surface:, intent: "sign_in", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
        )
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
        model = binding.class.auth_admission_session_class
        browser = open_session
        browser.host!(host)
        browser.https!
        headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        sid_key = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"

        if attack == "unattached"
          _continuity, retained_sid = model.issue!
          browser.cookies.merge("#{sid_key}=#{Rack::Utils.escape(retained_sid)}", URI.parse("https://#{host}/"))
        else
          attach_auth_ceremony_entry!("/sign/in", reference: issuance.reference, params: { ri: "jp" }, browser:)
          retained_sid = browser.cookies[sid_key]
          binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest) unless
            attack == "unconfirmed"
        end

        if attack == "missing_cookie"
          browser.cookies.delete(sid_key)
        elsif attack == "foreign_cookie"
          _foreign, foreign_sid = model.issue!
          browser.cookies.merge("#{sid_key}=#{Rack::Utils.escape(foreign_sid)}", URI.parse("https://#{host}/"))
        end

        before = binding.reload.attributes
        session_count = model.count
        original = Valkey::AuthState::OpaqueAdmissionStore.new.read_reference!(reference: issuance.reference)
        browser.get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers:)

        expected_status = %w(unconfirmed unattached).include?(attack) ? 303 : 400

        assert_equal expected_status, browser.response.status
        if %w(unconfirmed unattached).include?(attack)
          assert_equal "/ceremony_bindings", URI.parse(browser.response.location).path
        else
          assert_nil browser.response.location
        end

        assert_equal before, binding.reload.attributes
        assert_equal session_count, model.count
        assert_equal original,
                     Valkey::AuthState::OpaqueAdmissionStore.new.read_reference!(reference: issuance.reference)
        assert_nil binding.admitted_auth_ceremony_session_id

        # rubocop:disable Lint/Void -- Rack::Test::CookieJar#merge mutates the jar; it has no merge!.
        browser.cookies.merge("#{sid_key}=#{Rack::Utils.escape(retained_sid)}", URI.parse("https://#{host}/"))
        # rubocop:enable Lint/Void
        if attack == "unattached"
          attach_auth_ceremony_entry!("/sign/in", reference: issuance.reference, params: { ri: "jp" }, browser:)
        end
        binding.reload.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest) unless
          binding.confirmed?
        browser.get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers:)

        assert_equal 303, browser.response.status
        assert_predicate binding.reload, :redeemed?
        assert_predicate admitted_auth_ceremony_session_for_test(binding), :admitted?
        assert_equal session_count + 1, model.count
        assert_equal "pending", issuance.transaction.reload.status
        admitted_id = binding.admitted_auth_ceremony_session_id
        browser.get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers:)

        assert_equal [303, admitted_id, model.count],
                     [browser.response.status, binding.reload.admitted_auth_ceremony_session_id, session_count + 1]
      ensure
        ActionController::Base.allow_forgery_protection = protection
      end
    end
  end

  %w(app com org).each do |surface|
    %w(missing blank whitespace zero nul short long array object duplicate query_duplicate
       auth_sid sid auth_ceremony_session_id admitted_auth_ceremony_session_id base_token_id
       base_browser_digest confirmation_ref sign_in_flow_id authorization_transaction_id
       step_up_ceremony_transaction_id parent_kind purpose browser_nonce).each do |attack|
      test "#{surface} redemption refuses #{attack} without consuming or rotating continuity" do
        protection = ActionController::Base.allow_forgery_protection
        ActionController::Base.allow_forgery_protection = true
        host = auth_host_for_test(surface)
        issuance = OidcTestEntry.issue!(
          surface:, intent: "sign_in", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
        )
        browser = open_session
        browser.host!(host)
        browser.https!
        binding = attach_auth_ceremony_entry!(
          "/sign/in", reference: issuance.reference, params: { ri: "jp" }, browser:,
        )
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        session_model = binding.class.auth_admission_session_class
        session_count = session_model.count
        sid_key = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        retained_sid = browser.cookies[sid_key]
        original = Valkey::AuthState::OpaqueAdmissionStore.new.read_reference!(reference: issuance.reference)
        fields = { "entry_ref" => issuance.reference, "ri" => "jp" }
        case attack
        when "missing" then fields.delete("entry_ref")
        when "blank" then fields["entry_ref"] = ""
        when "whitespace" then fields["entry_ref"] = " "
        when "zero" then fields["entry_ref"] = "0"
        when "nul" then fields["entry_ref"] = "\0"
        when "short" then fields["entry_ref"] = issuance.reference[0...-1]
        when "long" then fields["entry_ref"] = "#{issuance.reference}0"
        when "array" then fields["entry_ref"] = [issuance.reference]
        when "object" then fields["entry_ref"] = { "value" => issuance.reference }
        when "duplicate", "query_duplicate"
        else fields[attack] = issuance.reference
        end
        path = "/sign/in"
        if attack == "duplicate"
          browser.get("#{path}?#{Rack::Utils.build_query(fields)}&entry_ref=#{issuance.reference}", headers:)
        elsif attack == "query_duplicate"
          browser.get("#{path}?entry_ref=#{issuance.reference}", params: fields, headers:)
        else
          browser.get(path, params: fields, headers:)
        end

        assert_equal [400, nil], [browser.response.status, browser.response.location]
        assert_equal session_count, session_model.count
        assert_equal retained_sid, browser.cookies[sid_key]
        assert_equal original,
                     Valkey::AuthState::OpaqueAdmissionStore.new.read_reference!(reference: issuance.reference)
        assert_equal "pending", issuance.transaction.reload.status
        assert_not_predicate binding.reload, :redeemed?
      ensure
        ActionController::Base.allow_forgery_protection = protection
      end
    end
  end

  private

  def auth_host_for_test(surface)
    {
      "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
      "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
    }.fetch(surface)
  end
end
