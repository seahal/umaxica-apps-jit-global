# frozen_string_literal: true

require "test_helper"

class AdmissionRedemptionInputBoundaryTest < ActionDispatch::IntegrationTest
  %w(app com org).each do |surface|
    %w(missing_cookie foreign_cookie unconfirmed unattached).each do |attack|
      test "#{surface} redemption refuses #{attack} then resumes only its retained confirmed binding" do
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
        model = binding.class.auth_admission_session_class
        browser = open_session
        browser.host!(host)
        browser.https!
        headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        browser.get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" })
        csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        fields = { entry_ref: issuance.reference, authenticity_token: csrf, ri: "jp" }
        sid_key = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        if attack == "unattached"
          _continuity, retained_sid = model.issue!
          browser.cookies.merge("#{sid_key}=#{Rack::Utils.escape(retained_sid)}", URI.parse("https://#{host}/"))
        else
          browser.post("/ceremony_bindings", params: fields, headers:)

          assert_equal 303, browser.response.status
          retained_sid = browser.cookies[sid_key]
          binding.reload.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest) unless
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
        browser.post("/sign/in", params: fields, headers:)

        assert_equal [400, nil], [browser.response.status, browser.response.location]
        assert_equal before, binding.reload.attributes
        assert_equal session_count, model.count
        assert_equal original,
                     Valkey::AuthState::OpaqueAdmissionStore.new.read_reference!(reference: issuance.reference)
        assert_nil binding.admitted_auth_ceremony_session_id
        # Restore only the original owning cookie/proof; no new parent, admission or opaque entry is issued.
        _restored_cookie = browser.cookies.merge(
          "#{sid_key}=#{Rack::Utils.escape(retained_sid)}", URI.parse("https://#{host}/"),
        )
        browser.post("/ceremony_bindings", params: fields, headers:) if attack == "unattached"
        binding.reload.confirm_base!(
          base_token: nil,
          browser_digest: binding.base_browser_digest,
        ) unless binding.confirmed?
        browser.get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" })
        csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        fields[:authenticity_token] = csrf
        browser.post("/sign/in", params: fields, headers:)

        assert_equal 303, browser.response.status
        assert_predicate binding.reload, :redeemed?
        assert_predicate admitted_auth_ceremony_session_for_test(binding), :admitted?
        assert_equal session_count + 1, model.count
        assert_predicate issuance.transaction.reload, :sign_in_primary_pending?
        admitted_id = binding.admitted_auth_ceremony_session_id
        browser.post("/sign/in", params: fields, headers:)

        assert_equal [303, admitted_id, session_count + 1],
                     [browser.response.status, binding.reload.admitted_auth_ceremony_session_id, model.count]
      ensure
        ActionController::Base.allow_forgery_protection = protection
      end
    end
  end

  %w(app com org).each do |surface|
    %w(redemption).each do |stage|
      %w(missing blank whitespace zero nul short long array object duplicate query_duplicate
         auth_sid sid auth_ceremony_session_id admitted_auth_ceremony_session_id base_token_id
         base_browser_digest confirmation_ref sign_in_flow_id authorization_transaction_id
         step_up_ceremony_transaction_id parent_kind purpose browser_nonce).each do |attack|
        test "#{surface} #{stage} refuses #{attack} without consuming or rotating continuity" do
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
          headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
          browser.get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" })
          csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
          if stage == "redemption"
            browser.post(
              "/ceremony_bindings", params: { entry_ref: issuance.reference,
                                              authenticity_token: csrf,
                                              ri: "jp", }, headers:,
            )

            assert_equal 303, browser.response.status
            # Confirmation browser ownership is covered by the independent Base HTTP matrix.
            binding.reload.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
          end
          before = binding.reload.attributes
          session_model = binding.class.auth_admission_session_class
          session_count = session_model.count
          sid_key = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
          retained_sid = browser.cookies[sid_key]
          original = Valkey::AuthState::OpaqueAdmissionStore.new.read_reference!(reference: issuance.reference)
          fields = { "entry_ref" => issuance.reference, "authenticity_token" => csrf, "ri" => "jp" }
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
          when "duplicate", "query_duplicate" # Raw pairs below preserve duplicates that Rails would merge.
          else fields[attack] = issuance.reference
          end
          path = (stage == "redemption") ? "/sign/in" : "/ceremony_bindings"
          if attack == "duplicate"
            body = Rack::Utils.build_query(fields) + "&entry_ref=#{issuance.reference}"
            browser.post(
              path, params: body,
                    headers: headers.merge("CONTENT_TYPE" => "application/x-www-form-urlencoded"),
            )
          elsif attack == "query_duplicate"
            browser.post("#{path}?entry_ref=#{issuance.reference}", params: fields, headers:)
          else
            browser.post(path, params: fields, headers:)
          end

          assert_equal [400, nil], [browser.response.status, browser.response.location]
          assert_equal before, binding.reload.attributes
          assert_equal session_count, session_model.count
          assert_equal retained_sid, browser.cookies[sid_key]
          assert_equal original,
                       Valkey::AuthState::OpaqueAdmissionStore.new.read_reference!(reference: issuance.reference)
          assert_predicate issuance.transaction.reload, :sign_in_primary_pending?
        ensure
          ActionController::Base.allow_forgery_protection = protection
        end
      end
    end
  end
end
