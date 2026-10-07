# frozen_string_literal: true

require "test_helper"

# Boolean comparisons keep OTP secrets and challenge digests out of assertion failure output.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/AssertPredicate
class EmailSignInFlowIsolationTest < ActionDispatch::IntegrationTest
  %w(app com).each do |surface|
    test "#{surface} issuance and resend stay on their admitted flow without rotating Contact OTP" do
      # Only rate-counter expiry follows the travelled request clock. All limits
      # remain active; the shared OTP verification budget still uses real Valkey.
      with_rate_limit_counters do
        previous_forgery_protection = ActionController::Base.allow_forgery_protection
        ActionController::Base.allow_forgery_protection = true
        TurnstileVerifierStub.challenge_enabled = true
        TurnstileVerifierStub.challenge_response = { "success" => true }
        address = "flow-isolation-#{SecureRandom.hex(10)}@example.test"
        actor, contact =
          if surface == "app"
            actor = Client.create!(id: SecureRandom.random_number(1 << 60), status_id: ClientStatus::ACTIVE)
            [actor, actor.client_emails.create!(
              address:, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
            ).tap(&:finalize_binding!),]
          else
            actor = Visitor.create!(id: SecureRandom.random_number(1 << 60), status_id: VisitorStatus::ACTIVE)
            [actor, actor.visitor_emails.create!(
              address:, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
            ).tap(&:finalize_binding!),]
          end
        source_generation = contact.attributes.slice(
          "otp_private_key", "otp_counter", "otp_expires_at", "otp_last_sent_at",
        )
        browsers = [open_session, open_session]
        admissions =
          browsers.map do |browser|
            browser.https!
            admit_auth_local_entry!(surface:, browser:)
          end
        ceremonies =
          admissions.map do |admission|
            binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: admission.reference)
            binding.class.auth_admission_session_class.find(binding.reload.admitted_auth_ceremony_session_id)
          end

        assert_not_equal ceremonies.first.id, ceremonies.last.id
        host = (surface == "app") ? ENV.fetch("PUBLIC_AUTH_SERVICE_URL") : ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        codes = []
        edit_props = []
        edit_csrf_tokens = []
        original_time = Time.current
        browsers.each_with_index do |browser, index|
          travel_to(original_time + (index * (CommonOtpPolicy::SEND_COOLDOWN + 1.second)))
          browser.get("/sign/in/email/new", params: { ri: "jp" })

          assert_equal 200, browser.response.status
          csrf_meta = browser.response.parsed_body.at_css('meta[name="csrf-token"]')

          assert csrf_meta.present?, "expected the rendered browser CSRF meta tag"
          csrf = csrf_meta["content"]
          address_field = (surface == "app") ? :client_email : :user_email
          delivery_count = ActionMailer::Base.deliveries.size
          perform_enqueued_jobs do
            browser.post(
              "/sign/in/email", params: {
                address_field => { address: },
                :authenticity_token => csrf,
                "cf-turnstile-response" => "test",
                :ri => "jp",
              }, headers:,
            )
          end

          assert_equal 302, browser.response.status
          assert_equal delivery_count + 1, ActionMailer::Base.deliveries.size
          delivery = ActionMailer::Base.deliveries.last

          assert_equal [address], delivery.to
          match = delivery.text_part.body.decoded.match(/Pass Code:\s*([0-9]{6})/)

          assert match.present?, "expected an OTP in the delivered text part"
          codes << match[1]

          assert source_generation == contact.reload.attributes.slice(*source_generation.keys),
                 "sign-in issuance must leave Contact OTP generation unchanged"
          browser.get(URI.parse(browser.response.location).request_uri, params: { ri: "jp" })

          assert_equal 200, browser.response.status
          edit_props << JSON.parse(browser.response.parsed_body.at_css('script[data-page="app"]').text).fetch("props")
          csrf_meta = browser.response.parsed_body.at_css('meta[name="csrf-token"]')

          assert csrf_meta.present?, "expected the rendered edit-page CSRF meta tag"
          edit_csrf_tokens << csrf_meta["content"]
          if index.zero?
            @first_context = ceremonies.first.reload.email_otp_context.deep_dup

            assert @first_context.present?, "issuance must persist a Ticket challenge"
            # B is genuinely throttled before the identifier window expires;
            # swapping the clock-aware store does not bypass the existing limit.
            browsers.last.get("/sign/in/email/new", params: { ri: "jp" })
            cooldown_csrf = browsers.last.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
            browsers.last.post(
              "/sign/in/email", params: {
                address_field => { address: },
                :authenticity_token => cooldown_csrf,
                "cf-turnstile-response" => "test",
                :ri => "jp",
              }, headers:,
            )

            assert_equal 429, browsers.last.response.status
            assert_equal delivery_count + 1, ActionMailer::Base.deliveries.size
            assert_nil ceremonies.last.reload.email_otp_context
            assert @first_context == ceremonies.first.reload.email_otp_context,
                   "throttled B receipt must leave A's challenge unchanged"
          else
            assert @first_context == ceremonies.first.reload.email_otp_context,
                   "another browser issuance must not rotate A's Ticket challenge"
          end
        end
        resend_key = (surface == "app") ? "otp_resend" : "resend"
        first_resend = edit_props.first.fetch(resend_key)
        second_resend = edit_props.last.fetch(resend_key)
        second_before = ceremonies.last.reload.email_otp_context.deep_dup
        browsers.last.post(
          second_resend.fetch("endpoint"), params: {
            state: first_resend.fetch("state"), authenticity_token: edit_csrf_tokens.last,
          }, headers:, as: :json,
        )

        assert_equal 400, browsers.last.response.status
        assert @first_context == ceremonies.first.reload.email_otp_context,
               "foreign resend state must not mutate A"
        assert second_before == ceremonies.last.reload.email_otp_context,
               "foreign resend state must not mutate B"

        travel_to(original_time + (2 * (CommonOtpPolicy::SEND_COOLDOWN + 1.second)))
        delivery_count = ActionMailer::Base.deliveries.size
        perform_enqueued_jobs do
          browsers.last.post(
            second_resend.fetch("endpoint"), params: {
              state: second_resend.fetch("state"), authenticity_token: edit_csrf_tokens.last,
            }, headers:, as: :json,
          )
        end

        assert_equal 200, browsers.last.response.status
        assert_equal delivery_count + 1, ActionMailer::Base.deliveries.size
        assert source_generation == contact.reload.attributes.slice(*source_generation.keys),
               "resend must leave Contact OTP generation unchanged"
        assert @first_context == ceremonies.first.reload.email_otp_context,
               "B resend must leave A's challenge unchanged"
        assert_not_equal second_before.fetch("generation"), ceremonies.last.reload.email_otp_context.fetch("generation")
        assert_nil ceremonies.last.email_otp_context.fetch("verified_at")

        # A's delivered code remains usable after B issues and resends. No root login is
        # granted on Auth: success records evidence only on A's already admitted parent.
        code_field = (surface == "app") ? :client_email : :user_email
        browsers.first.patch(
          "/sign/in/email", params: {
            code_field => { pass_code: codes.first },
            :authenticity_token => edit_csrf_tokens.first,
            "cf-turnstile-response" => "test",
            :ri => "jp",
          }, headers:,
        )

        # APP preserves its Found response; COM explicitly uses See Other after verification.
        assert_equal((surface == "app") ? 302 : 303, browsers.first.response.status)
        assert ceremonies.first.reload.email_otp_context.fetch("verified_at").present?
        assert_nil ceremonies.last.reload.email_otp_context.fetch("verified_at")
        assert_equal actor.public_id, ceremonies.first.email_otp_context.fetch("owner_ref")
      ensure
        travel_back
        ActionController::Base.allow_forgery_protection = previous_forgery_protection
        TurnstileVerifierStub.challenge_enabled = false
        TurnstileVerifierStub.challenge_response = nil
      end
    end
  end
end
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/AssertPredicate
