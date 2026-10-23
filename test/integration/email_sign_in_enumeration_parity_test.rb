# frozen_string_literal: true

require "test_helper"

class EmailSignInEnumerationParityTest < ActionDispatch::IntegrationTest
  setup do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  %w(app com).each do |surface|
    test "#{surface} email OTP cancellation refuses a browser without sign-in admission" do
      browser = open_session
      host = (surface == "app") ? ENV.fetch("PUBLIC_AUTH_SERVICE_URL") : ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
      browser.host!(host)

      browser.delete("/sign/in/email")

      assert_equal 400, browser.response.status
    end
  end

  %w(app com).each do |surface|
    test "#{surface} real and dummy code entry share microsecond expiry boundaries" do
      address = "expiry-real-#{SecureRandom.hex(8)}@example.test"
      if surface == "app"
        owner = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
        )
        owner.client_emails.create!(
          address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
        ).finalize_binding!
      else
        owner = Visitor.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
          status_id: VisitorStatus::ACTIVE,
        )
        owner.visitor_emails.create!(
          address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        ).finalize_binding!
      end
      model = (surface == "app") ? ClientAuthCeremonySession : VisitorAuthCeremonySession
      cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      paths = {}
      [["real", address], ["fake", "expiry-fake-#{SecureRandom.hex(8)}@example.test"]].each do |mode, destination|
        browser = open_session
        begin
          admission_browser = browser
          admission_surface = surface
          admission_intent = "sign_in"
          admission_host = {
            "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
            "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
          }.fetch(admission_surface)
          admission_browser.host!(admission_host)
          admission_issuance = OidcTestEntry.issue!(
            surface: admission_surface, intent: admission_intent,
            base_browser_nonce: SecureRandom.hex(32), base_token: nil,
          )
          admission_path = "/sign/#{(admission_intent == "sign_up") ? "up" : "in"}"
          admission_browser.get(
            admission_path,
            params: { entry_ref: admission_issuance.reference, ri: "jp" },
          )
          admission_csrf = admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
          admission_browser.post(
            "/ceremony_bindings",
            params: { entry_ref: admission_issuance.reference,
                      authenticity_token: admission_csrf,
                      ri: "jp", },
          )

          assert_equal 303, admission_browser.response.status
          admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
            surface: admission_surface, reference: admission_issuance.reference,
          )
          admission_binding.reload.confirm_base!(
            base_token: nil,
            browser_digest: admission_binding.base_browser_digest,
          )
          admission_browser.get(
            admission_path,
            params: { entry_ref: admission_issuance.reference, ri: "jp" },
          )
          admission_csrf = admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
          admission_browser.post(
            admission_path,
            params: { entry_ref: admission_issuance.reference,
                      authenticity_token: admission_csrf,
                      ri: "jp", },
          )

          assert_equal 303, admission_browser.response.status
        end
        phase_binding = nil
        browser.post(
          "/sign/in/email", params: {
            :user_email => { address: destination }, "cf-turnstile-response" => "test", :fb => phase_binding,
          },
        )

        assert_equal 302, browser.response.status
        entry = URI.parse(browser.response.location).request_uri
        ceremony = model.find_active_by_raw_sid(browser.cookies[cookie_name])
        original = ceremony.email_otp_context.deep_dup
        deadline = Time.iso8601(original.fetch("expires_at"))
        [-1, 0, 1].each do |microseconds|
          model.stub(:database_now, deadline + Rational(microseconds, 1_000_000)) do
            browser.get(entry, params: { ri: "jp" })
          end

          assert_equal microseconds.negative? ? 200 : 302, browser.response.status
          paths[[mode, microseconds]] = URI.parse(browser.response.location).path unless microseconds.negative?
          unchanged = original == ceremony.reload.email_otp_context

          assert unchanged, "expiry evaluation must retain challenge history"
        end
      end

      [0, 1].each do |microseconds|
        assert_equal paths.fetch(["real", microseconds]), paths.fetch(["fake", microseconds])
      end
    end

    test "#{surface} real and dummy receipt and wrong OTP expose the same controls and feedback" do
      address = "parity-real-#{SecureRandom.hex(8)}@example.test"
      case surface
      when "app"
        actor = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
        )
        contact = actor.client_emails.create!(
          address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      when "com"
        actor = Visitor.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE,
        )
        contact = actor.visitor_emails.create!(
          address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      end
      real = open_session
      dummy = open_session
      source_generation = contact.attributes.slice(
        "public_id", "address_digest", "number_digest", "user_id",
        "visitor_id", "staff_id",
      )
      begin
        admission_browser = real
        admission_surface = surface
        admission_intent = "sign_in"
        admission_host = {
          "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
          "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
          "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
        }.fetch(admission_surface)
        admission_browser.host!(admission_host)
        admission_issuance = OidcTestEntry.issue!(
          surface: admission_surface, intent: admission_intent,
          base_browser_nonce: SecureRandom.hex(32), base_token: nil,
        )
        admission_path = "/sign/#{(admission_intent == "sign_up") ? "up" : "in"}"
        admission_browser.get(
          admission_path,
          params: { entry_ref: admission_issuance.reference, ri: "jp" },
        )
        admission_csrf = admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        admission_browser.post(
          "/ceremony_bindings",
          params: { entry_ref: admission_issuance.reference, authenticity_token: admission_csrf, ri: "jp" },
        )

        assert_equal 303, admission_browser.response.status
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: admission_surface, reference: admission_issuance.reference,
        )
        admission_binding.reload.confirm_base!(
          base_token: nil,
          browser_digest: admission_binding.base_browser_digest,
        )
        admission_browser.get(
          admission_path,
          params: { entry_ref: admission_issuance.reference, ri: "jp" },
        )
        admission_csrf = admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        admission_browser.post(
          admission_path,
          params: { entry_ref: admission_issuance.reference, authenticity_token: admission_csrf, ri: "jp" },
        )

        assert_equal 303, admission_browser.response.status
      end
      real_phase_binding = nil
      begin
        admission_browser = dummy
        admission_surface = surface
        admission_intent = "sign_in"
        admission_host = {
          "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
          "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
          "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
        }.fetch(admission_surface)
        admission_browser.host!(admission_host)
        admission_issuance = OidcTestEntry.issue!(
          surface: admission_surface, intent: admission_intent,
          base_browser_nonce: SecureRandom.hex(32), base_token: nil,
        )
        admission_path = "/sign/#{(admission_intent == "sign_up") ? "up" : "in"}"
        admission_browser.get(
          admission_path,
          params: { entry_ref: admission_issuance.reference, ri: "jp" },
        )
        admission_csrf = admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        admission_browser.post(
          "/ceremony_bindings",
          params: { entry_ref: admission_issuance.reference, authenticity_token: admission_csrf, ri: "jp" },
        )

        assert_equal 303, admission_browser.response.status
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: admission_surface, reference: admission_issuance.reference,
        )
        admission_binding.reload.confirm_base!(
          base_token: nil,
          browser_digest: admission_binding.base_browser_digest,
        )
        admission_browser.get(
          admission_path,
          params: { entry_ref: admission_issuance.reference, ri: "jp" },
        )
        admission_csrf = admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        admission_browser.post(
          admission_path,
          params: { entry_ref: admission_issuance.reference, authenticity_token: admission_csrf, ri: "jp" },
        )

        assert_equal 303, admission_browser.response.status
      end
      dummy_phase_binding = nil
      paths = []
      # Equal-length input isolates binding-existence leakage from the caller-known address length.
      [[real, address], [dummy, "parity-fake-#{SecureRandom.hex(8)}@example.test"]].each do |browser, destination|
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        browser.post(
          "/sign/in/email", params: {
            :user_email => { address: destination },
            "cf-turnstile-response" => "test",
            :fb => ((browser == real) ? real_phase_binding : dummy_phase_binding),
          },
        )

        assert_equal 302, browser.response.status
        assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :>=, 0.1
        paths << URI.parse(browser.response.location).path
        browser.get(URI.parse(browser.response.location).request_uri, params: { ri: "jp" })

        assert_equal 200, browser.response.status
      end
      assert_equal paths.first, paths.last
      real_props =
        begin
          fv5009 = real
          fv5008 = fv5009.response.parsed_body.at_css('script[data-page="app"]')

          assert fv5008, "expected a rendered Inertia page"
          JSON.parse(fv5008.text).fetch("props")
        end
      dummy_props =
        begin
          fv5007 = dummy
          fv5006 = fv5007.response.parsed_body.at_css('script[data-page="app"]')

          assert fv5006, "expected a rendered Inertia page"
          JSON.parse(fv5006.text).fetch("props")
        end
      resend_key = (surface == "app") ? "otp_resend" : "resend"

      # Each admitted flow receives its own purpose-bound capability.  It is intentionally
      # different between the real and dummy browser, so compare the rendered contract after
      # removing only that opaque binding while retaining the rest of the page shape.
      [real_props, dummy_props].each do |props|
        container = props.fetch("form", props)
        action = container.fetch("action")
        query = Rack::Utils.parse_nested_query(URI.parse(action).query.to_s)
        query.delete("fb")
        uri = URI.parse(action)
        uri.query = URI.encode_www_form(query)
        container["action"] = uri.path + (uri.query.present? ? "?#{uri.query}" : "")
      end

      assert_equal real_props.fetch(resend_key).fetch("state").bytesize,
                   dummy_props.fetch(resend_key).fetch("state").bytesize
      assert_equal real_props.except(resend_key, "authenticity_token"),
                   dummy_props.except(resend_key, "authenticity_token")
      assert_equal real_props.fetch(resend_key).except("state"), dummy_props.fetch(resend_key).except("state")

      [real, dummy].each do |browser|
        state = begin
          fv5005 = browser
          fv5004 = fv5005.response.parsed_body.at_css('script[data-page="app"]')

          assert fv5004, "expected a rendered Inertia page"
          JSON.parse(fv5004.text).fetch("props")
        end.fetch(resend_key).fetch("state")
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        browser.post("/web/v0/in/email/otp", params: { state: state }, as: :json)

        assert_equal 200, browser.response.status
        assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :>=, 0.1
      end
      model = (surface == "app") ? ClientAuthCeremonySession : VisitorAuthCeremonySession
      cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      ceremony = model.find_active_by_raw_sid(real.cookies[cookie_name])
      context = ceremony.email_otp_context
      comparison = AuthEmailOtpCodeDigest.for(context: context, code: "000000")
      wrong = (comparison == context.fetch("code_digest")) ? "111111" : "000000"
      [real, dummy].each do |browser|
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        browser.patch(
          "/sign/in/email", params: {
            :user_email => { pass_code: wrong },
            "cf-turnstile-response" => "test",
            :fb => ((browser == real) ? real_phase_binding : dummy_phase_binding),
          },
        )

        assert_equal 422, browser.response.status
        assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :>=, 0.1
      end
      real_refusal =
        begin
          fv5003 = real
          fv5002 = fv5003.response.parsed_body.at_css('script[data-page="app"]')

          assert fv5002, "expected a rendered Inertia page"
          JSON.parse(fv5002.text).fetch("props")
        end
      dummy_refusal =
        begin
          fv5001 = dummy
          fv5000 = fv5001.response.parsed_body.at_css('script[data-page="app"]')

          assert fv5000, "expected a rendered Inertia page"
          JSON.parse(fv5000.text).fetch("props")
        end

      [real_refusal, dummy_refusal].each do |props|
        container = props.fetch("form", props)
        action = container.fetch("action")
        query = Rack::Utils.parse_nested_query(URI.parse(action).query.to_s)
        query.delete("fb")
        uri = URI.parse(action)
        uri.query = URI.encode_www_form(query)
        container["action"] = uri.path + (uri.query.present? ? "?#{uri.query}" : "")
      end

      assert_equal real_refusal.except(resend_key, "authenticity_token"),
                   dummy_refusal.except(resend_key, "authenticity_token")
      assert_not_empty real_refusal.fetch("form_errors")
      assert_equal real_refusal.fetch(resend_key).except("state"), dummy_refusal.fetch(resend_key).except("state")
      # Boolean assertions keep OTP key material out of failure output.
      source_unchanged = source_generation == contact.reload.attributes.slice(*source_generation.keys)

      assert source_unchanged,
             "flow-specific wrong-code verification must not rotate the Source OTP generation"

      cancellation_paths = []
      [real, dummy].each do |browser|
        browser.delete(
          "/sign/in/email",
          params: { pt: nil, fb: ((browser == real) ? real_phase_binding : dummy_phase_binding) },
        )

        assert_equal 303, browser.response.status
        cancellation_paths << URI.parse(browser.response.location).path
        cancelled = model.find_active_by_raw_sid(browser.cookies[cookie_name])

        assert cancelled.reload.email_otp_context.fetch("cancelled_at")
        expected_contact = (browser == real) ? contact : nil

        assert_not cancelled.email_otp_challenge_current?(contact: expected_contact)
        assert_equal :missing_challenge, cancelled.verify_email_otp!(code: wrong).status
        browser.get(
          "/sign/in/email/edit",
          params: { ri: "jp", fb: ((browser == real) ? real_phase_binding : dummy_phase_binding) },
        )

        assert_equal 302, browser.response.status
      end
      assert_equal cancellation_paths.first, cancellation_paths.last
    end
  end

  private
end
