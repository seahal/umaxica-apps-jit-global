# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"

module Auth
  module App
    module In
      # The email sign-in flow is deliberately built for non-disclosure: it performs
      # dummy OTP work, stores dummy state, and normalizes elapsed time so that an
      # unregistered address is indistinguishable from a registered one.
      #
      # The cooldown response used to break that by returning a different message
      # when the address belonged to a login-eligible account, which made resubmitting
      # the same address twice an account-existence oracle.
      class EmailsControllerEnumerationTest < ActionDispatch::IntegrationTest
        rate_limit_counters!

        fixtures :clients, :client_statuses, :client_email_statuses

        REGISTERED_ADDRESS = "enumeration_registered@example.com"
        UNREGISTERED_ADDRESS = "enumeration_unregistered@example.com"

        setup do
          host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          TurnstileVerifierStub.challenge_enabled = true
          TurnstileVerifierStub.challenge_response = { "success" => true }

          clients(:one).update!(status_id: ClientStatus::ACTIVE)
          ClientEmail.create!(
            user: clients(:one), address: REGISTERED_ADDRESS, confirm_policy: true,
            user_email_status_id: ClientEmailStatus::VERIFIED,
          ).tap(&:finalize_binding!)
        end

        teardown do
          TurnstileVerifierStub.challenge_enabled = false
          TurnstileVerifierStub.challenge_response = nil
        end

        test "the cooldown response is identical for registered and unregistered addresses" do
          registered =
            begin
              fx0_address = REGISTERED_ADDRESS
              fx0_responses =
                2.times.map do
                  fx0_response = nil
                  open_session do |fx0_session|
                    fx0_session.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
                    begin
                      entry0_browser = fx0_session
                      entry0_surface = "app"
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
                      entry0_phase_binding = SignInFlowBindingCodec.encode(
                        flow: ClientSignInFlow.find_by!(
                          public_id: entry0_binding.reload.admitted_auth_ceremony_session.local_sign_in_flow_ref,
                        ),
                        surface: "app", phase: "PRIMARY_PENDING",
                      )
                    end
                    fx0_session.post(
                      auth_app_sign_in_email_url(ri: "jp", fb: entry0_phase_binding), params: {
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
                    fx1_session.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
                    begin
                      entry1_browser = fx1_session
                      entry1_surface = "app"
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
                      entry1_phase_binding = SignInFlowBindingCodec.encode(
                        flow: ClientSignInFlow.find_by!(
                          public_id: entry1_binding.reload.admitted_auth_ceremony_session.local_sign_in_flow_ref,
                        ),
                        surface: "app", phase: "PRIMARY_PENDING",
                      )
                    end
                    fx1_session.post(
                      auth_app_sign_in_email_url(ri: "jp", fb: entry1_phase_binding), params: {
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

          assert_equal 429, registered[:status],
                       "Resubmitting the same address inside the send cooldown must be rate limited."
          assert_equal registered[:status], unregistered[:status],
                       "A different status code for a registered address leaks account existence."
          assert_equal registered[:body], unregistered[:body],
                       "A different cooldown message for a registered address leaks account existence. " \
                       "Registered: #{registered[:body].inspect}, unregistered: #{unregistered[:body].inspect}"
        end

        test "a failed Turnstile request does not reserve the address-wide bucket" do
          TurnstileVerifierStub.challenge_response = { "success" => false }
          open_session do |session|
            session.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
            begin
              admission_browser = session
              admission_surface = "app"
              admission_intent = "sign_in"
              admission_host = {
                "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
                "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
              }.fetch(admission_surface)
              admission_browser.host!(admission_host)
              admission_issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
                surface: admission_surface, intent: admission_intent,
                base_browser_nonce: SecureRandom.hex(32), base_token: nil,
              )
              admission_path = "/sign/#{(admission_intent == "sign_up") ? "up" : "in"}"
              admission_browser.get(
                admission_path,
                params: { entry_ref: admission_issuance.reference, ri: "jp" },
              )
              admission_csrf =
                admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
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
              admission_csrf =
                admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
              admission_browser.post(
                admission_path,
                params: { entry_ref: admission_issuance.reference,
                          authenticity_token: admission_csrf,
                          ri: "jp", },
              )

              assert_equal 303, admission_browser.response.status
              phase_binding = SignInFlowBindingCodec.encode(
                flow: ClientSignInFlow.find_by!(
                  public_id: admission_binding.reload.admitted_auth_ceremony_session.local_sign_in_flow_ref,
                ),
                surface: "app", phase: "PRIMARY_PENDING",
              )
            end
            session.post(
              auth_app_sign_in_email_url(ri: "jp", fb: phase_binding), params: {
                :user_email => { address: REGISTERED_ADDRESS },
                "cf-turnstile-response" => "invalid_token",
              },
            )

            assert_equal 422, session.response.status
          end

          TurnstileVerifierStub.challenge_response = { "success" => true }
          open_session do |session|
            session.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
            begin
              admission_browser = session
              admission_surface = "app"
              admission_intent = "sign_in"
              admission_host = {
                "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
                "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
              }.fetch(admission_surface)
              admission_browser.host!(admission_host)
              admission_issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
                surface: admission_surface, intent: admission_intent,
                base_browser_nonce: SecureRandom.hex(32), base_token: nil,
              )
              admission_path = "/sign/#{(admission_intent == "sign_up") ? "up" : "in"}"
              admission_browser.get(
                admission_path,
                params: { entry_ref: admission_issuance.reference, ri: "jp" },
              )
              admission_csrf =
                admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
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
              admission_csrf =
                admission_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
              admission_browser.post(
                admission_path,
                params: { entry_ref: admission_issuance.reference,
                          authenticity_token: admission_csrf,
                          ri: "jp", },
              )

              assert_equal 303, admission_browser.response.status
              phase_binding = SignInFlowBindingCodec.encode(
                flow: ClientSignInFlow.find_by!(
                  public_id: admission_binding.reload.admitted_auth_ceremony_session.local_sign_in_flow_ref,
                ),
                surface: "app", phase: "PRIMARY_PENDING",
              )
            end
            session.post(
              auth_app_sign_in_email_url(ri: "jp", fb: phase_binding), params: {
                :user_email => { address: REGISTERED_ADDRESS },
                "cf-turnstile-response" => "valid_token",
              },
            )

            assert_equal 302, session.response.status
          end
        end

        private

        # Submits each request in a fresh session so a browser cookie cannot hide
        # a server-side registered/unregistered difference.
      end
    end
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
