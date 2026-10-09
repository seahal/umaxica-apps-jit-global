# typed: false
# frozen_string_literal: true

require "test_helper"

module Auth
  module Com
    module In
      class EmailsControllerEnumerationTest < ActionDispatch::IntegrationTest
        rate_limit_counters!

        REGISTERED_ADDRESS = "com_enumeration_registered@example.com"
        UNREGISTERED_ADDRESS = "com_enumeration_unregistered@example.com"

        setup do
          host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
          TurnstileVerifierStub.challenge_enabled = true
          TurnstileVerifierStub.challenge_response = { "success" => true }

          visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
          VisitorEmail.create!(
            visitor: visitor, address: REGISTERED_ADDRESS, confirm_policy: true,
            visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          ).tap(&:finalize_binding!)
        end

        teardown do
          TurnstileVerifierStub.challenge_enabled = false
          TurnstileVerifierStub.challenge_response = nil
        end

        test "fresh sessions receive the same cooldown response for registered and unregistered addresses" do
          registered =
            begin
              fx0_address = REGISTERED_ADDRESS
              fx0_responses =
                2.times.map do
                  fx0_response = nil
                  open_session do |fx0_session|
                    fx0_session.host!(ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"))
                    begin
                      entry0_browser = fx0_session
                      entry0_surface = "com"
                      entry0_intent = "sign_in"
                      entry0_host = {
                        "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                        "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
                        "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
                      }.fetch(entry0_surface)
                      entry0_browser.host!(entry0_host)
                      entry0_issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
                        surface: entry0_surface, intent: entry0_intent,
                        base_browser_nonce: SecureRandom.hex(32), base_token: nil,
                      )
                      entry0_path = "/sign/#{(entry0_intent == "sign_up") ? "up" : "in"}"
                      entry0_browser.get(
                        entry0_path,
                        params: { entry_ref: entry0_issuance.reference, ri: "jp" },
                      )
                      entry0_csrf =
                        entry0_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
                      entry0_browser.post(
                        "/ceremony_bindings",
                        params: { entry_ref: entry0_issuance.reference,
                                  authenticity_token: entry0_csrf,
                                  ri: "jp", },
                      )

                      assert_equal 303, entry0_browser.response.status
                      entry0_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
                        surface: entry0_surface, reference: entry0_issuance.reference,
                      )
                      entry0_binding.reload.confirm_base!(
                        base_token: nil,
                        browser_digest: entry0_binding.base_browser_digest,
                      )
                      entry0_browser.get(
                        entry0_path,
                        params: { entry_ref: entry0_issuance.reference, ri: "jp" },
                      )
                      entry0_csrf =
                        entry0_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
                      entry0_browser.post(
                        entry0_path,
                        params: { entry_ref: entry0_issuance.reference,
                                  authenticity_token: entry0_csrf,
                                  ri: "jp", },
                      )

                      assert_equal 303, entry0_browser.response.status
                    end
                    fx0_session.post(
                      auth_com_sign_in_email_url(ri: "jp"), params: {
                        :user_email => { address: fx0_address },
                        "cf-turnstile-response" => "test_token",
                      },
                    )
                    fx0_response = {
                      status: fx0_session.response.status,
                      body: fx0_session.response.body,
                    }
                  end
                  fx0_response
                end

              fx0_responses.last
            end
          unregistered =
            begin
              fx1_address = UNREGISTERED_ADDRESS
              fx1_responses =
                2.times.map do
                  fx1_response = nil
                  open_session do |fx1_session|
                    fx1_session.host!(ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"))
                    begin
                      entry1_browser = fx1_session
                      entry1_surface = "com"
                      entry1_intent = "sign_in"
                      entry1_host = {
                        "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                        "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
                        "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
                      }.fetch(entry1_surface)
                      entry1_browser.host!(entry1_host)
                      entry1_issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
                        surface: entry1_surface, intent: entry1_intent,
                        base_browser_nonce: SecureRandom.hex(32), base_token: nil,
                      )
                      entry1_path = "/sign/#{(entry1_intent == "sign_up") ? "up" : "in"}"
                      entry1_browser.get(
                        entry1_path,
                        params: { entry_ref: entry1_issuance.reference, ri: "jp" },
                      )
                      entry1_csrf =
                        entry1_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
                      entry1_browser.post(
                        "/ceremony_bindings",
                        params: { entry_ref: entry1_issuance.reference,
                                  authenticity_token: entry1_csrf,
                                  ri: "jp", },
                      )

                      assert_equal 303, entry1_browser.response.status
                      entry1_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
                        surface: entry1_surface, reference: entry1_issuance.reference,
                      )
                      entry1_binding.reload.confirm_base!(
                        base_token: nil,
                        browser_digest: entry1_binding.base_browser_digest,
                      )
                      entry1_browser.get(
                        entry1_path,
                        params: { entry_ref: entry1_issuance.reference, ri: "jp" },
                      )
                      entry1_csrf =
                        entry1_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
                      entry1_browser.post(
                        entry1_path,
                        params: { entry_ref: entry1_issuance.reference,
                                  authenticity_token: entry1_csrf,
                                  ri: "jp", },
                      )

                      assert_equal 303, entry1_browser.response.status
                    end
                    fx1_session.post(
                      auth_com_sign_in_email_url(ri: "jp"), params: {
                        :user_email => { address: fx1_address },
                        "cf-turnstile-response" => "test_token",
                      },
                    )
                    fx1_response = {
                      status: fx1_session.response.status,
                      body: fx1_session.response.body,
                    }
                  end
                  fx1_response
                end

              fx1_responses.last
            end

          assert_equal 429, registered[:status]
          assert_equal registered[:status], unregistered[:status]
          assert_equal registered[:body], unregistered[:body]
        end

        private
      end
    end
  end
end
