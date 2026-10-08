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
    test "#{surface} real and dummy code entry share microsecond expiry boundaries" do
      address = "expiry-real-#{SecureRandom.hex(8)}@example.test"
      if surface == "app"
        owner = Client.create!(id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE)
        owner.client_emails.create!(
          address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
        ).finalize_binding!
      else
        owner = Visitor.create!(id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE)
        owner.visitor_emails.create!(
          address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        ).finalize_binding!
      end
      model = (surface == "app") ? ClientAuthCeremonySession : VisitorAuthCeremonySession
      cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      paths = {}
      [["real", address], ["fake", "expiry-fake-#{SecureRandom.hex(8)}@example.test"]].each do |mode, destination|
        browser = open_session
        admit_auth_local_entry!(surface: surface, browser: browser)
        browser.post(
          "/sign/in/email", params: {
            :user_email => { address: destination }, "cf-turnstile-response" => "test",
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
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
        )
        contact = actor.client_emails.create!(
          address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      when "com"
        actor = Visitor.create!(
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE,
        )
        contact = actor.visitor_emails.create!(
          address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        ).tap(&:finalize_binding!)
      end
      real = open_session
      dummy = open_session
      source_generation = contact.attributes.slice("otp_private_key", "otp_counter", "otp_expires_at")
      admit_auth_local_entry!(surface: surface, browser: real)
      admit_auth_local_entry!(surface: surface, browser: dummy)
      paths = []
      # Equal-length input isolates binding-existence leakage from the caller-known address length.
      [[real, address], [dummy, "parity-fake-#{SecureRandom.hex(8)}@example.test"]].each do |browser, destination|
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        browser.post(
          "/sign/in/email", params: {
            :user_email => { address: destination }, "cf-turnstile-response" => "test",
          },
        )

        assert_equal 302, browser.response.status
        assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :>=, 0.1
        paths << URI.parse(browser.response.location).path
        browser.get(URI.parse(browser.response.location).request_uri, params: { ri: "jp" })

        assert_equal 200, browser.response.status
      end
      assert_equal paths.first, paths.last
      real_props = page_props(real)
      dummy_props = page_props(dummy)
      resend_key = (surface == "app") ? "otp_resend" : "resend"

      assert_equal real_props.fetch(resend_key).fetch("state").bytesize,
                   dummy_props.fetch(resend_key).fetch("state").bytesize
      assert_equal real_props.except(resend_key, "authenticity_token"),
                   dummy_props.except(resend_key, "authenticity_token")
      assert_equal real_props.fetch(resend_key).except("state"), dummy_props.fetch(resend_key).except("state")

      [real, dummy].each do |browser|
        state = page_props(browser).fetch(resend_key).fetch("state")
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
            :user_email => { pass_code: wrong }, "cf-turnstile-response" => "test",
          },
        )

        assert_equal 422, browser.response.status
        assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :>=, 0.1
      end
      real_refusal = page_props(real)
      dummy_refusal = page_props(dummy)

      assert_equal real_refusal.except(resend_key, "authenticity_token"),
                   dummy_refusal.except(resend_key, "authenticity_token")
      assert_not_empty real_refusal.fetch("form_errors")
      assert_equal real_refusal.fetch(resend_key).except("state"), dummy_refusal.fetch(resend_key).except("state")
      # Boolean assertions keep OTP key material out of failure output.
      source_unchanged = source_generation == contact.reload.attributes.slice(*source_generation.keys)

      assert source_unchanged,
             "flow-specific wrong-code verification must not rotate the Source OTP generation"
    end
  end

  private

  def page_props(browser)
    page = browser.response.parsed_body.at_css('script[data-page="app"]')

    assert page, "expected a rendered Inertia page"
    JSON.parse(page.text).fetch("props")
  end
end
