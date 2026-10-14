# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Auth
  module App
    module In
      class EmailsControllerSecurityTest < ActionDispatch::IntegrationTest
        include ActiveSupport::Testing::TimeHelpers

        fixtures :clients, :client_statuses, :client_email_statuses

        setup do
          host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          begin
            admission_browser = self
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
            @primary_sign_in_binding = SignInFlowBindingCodec.encode(
              flow: ClientSignInFlow.find_by!(
                public_id: ClientAuthCeremonySession.find(
                  admission_binding.reload.admitted_auth_ceremony_session_id,
                ).local_sign_in_flow_ref,
              ),
              surface: "app", phase: "PRIMARY_PENDING",
            )
          end
          TurnstileVerifierStub.challenge_enabled = true
          TurnstileVerifierStub.challenge_response = { "success" => true }
        end

        teardown do
          TurnstileVerifierStub.challenge_enabled = false
          TurnstileVerifierStub.challenge_response = nil
        end

        test "rejects invalid email format" do
          post auth_app_sign_in_email_url(ri: "jp", fb: @primary_sign_in_binding), params: {
            user_email: { address: "invalid-email" },
          }

          assert_response :unprocessable_content
        end

        test "accepts valid emails with consecutive special characters" do
          # Test that user+tag@example.co.uk format is accepted
          # (This will redirect because email doesn't exist, preventing enumeration)
          post auth_app_sign_in_email_url(ri: "jp", fb: @primary_sign_in_binding), params: {
            :user_email => { address: "user+tag@example.co.uk" },
            "cf-turnstile-response" => "test_token",
          }

          # Should proceed past format validation
          assert_response :found
        end

        test "accepts valid emails with dots in local part" do
          post auth_app_sign_in_email_url(ri: "jp", fb: @primary_sign_in_binding), params: {
            :user_email => { address: "user.name@example.com" },
            "cf-turnstile-response" => "test_token",
          }

          # Should proceed past format validation
          assert_response :found
        end

        test "accepts valid emails with underscores" do
          post auth_app_sign_in_email_url(ri: "jp", fb: @primary_sign_in_binding), params: {
            :user_email => { address: "user_name@example.co.uk" },
            "cf-turnstile-response" => "test_token",
          }

          # Should proceed past format validation
          assert_response :found
        end

        test "accepts Gmail-style addressing with plus" do
          post auth_app_sign_in_email_url(ri: "jp", fb: @primary_sign_in_binding), params: {
            :user_email => { address: "user+mailbox@gmail.com" },
            "cf-turnstile-response" => "test_token",
          }

          # Should proceed past format validation
          assert_response :found
        end

        test "accepts emails with multiple domain levels" do
          post auth_app_sign_in_email_url(ri: "jp", fb: @primary_sign_in_binding), params: {
            :user_email => { address: "user@mail.example.co.uk" },
            "cf-turnstile-response" => "test_token",
          }

          # Should proceed past format validation
          assert_response :found
        end

        test "rejects emails without @ symbol" do
          post auth_app_sign_in_email_url(ri: "jp", fb: @primary_sign_in_binding), params: {
            user_email: { address: "usernameexample.com" },
          }

          assert_response :unprocessable_content
        end

        test "rejects emails without domain" do
          post auth_app_sign_in_email_url(ri: "jp", fb: @primary_sign_in_binding), params: {
            user_email: { address: "user@" },
          }

          assert_response :unprocessable_content
        end

        test "rejects emails without local part" do
          post auth_app_sign_in_email_url(ri: "jp", fb: @primary_sign_in_binding), params: {
            user_email: { address: "@example.com" },
          }

          assert_response :unprocessable_content
        end

        test "rejects emails with spaces" do
          post auth_app_sign_in_email_url(ri: "jp", fb: @primary_sign_in_binding), params: {
            user_email: { address: "user name@example.com" },
          }

          assert_response :unprocessable_content
        end

        test "normalizes email to lowercase" do
          post auth_app_sign_in_email_url(ri: "jp", fb: @primary_sign_in_binding), params: {
            :user_email => { address: "TEST@EXAMPLE.COM" },
            "cf-turnstile-response" => "test_token",
          }

          # Email should be normalized to lowercase in validation and proceed
          assert_response :found
        end

        test "rejects emails with excessive whitespace" do
          post auth_app_sign_in_email_url(ri: "jp", fb: @primary_sign_in_binding), params: {
            :user_email => { address: "  test@example.com  " },
            "cf-turnstile-response" => "test_token",
          }

          # Whitespace should be stripped and validated, then proceed
          assert_response :found
        end

        test "does not persist identifier-owned HOTP proof for a sign-in request" do
          user = clients(:one)
          # Create existing email
          email = ClientEmail.create!(
            user: user, address: "otp_test@example.com", confirm_policy: true,
            user_email_status_id: ClientEmailStatus::VERIFIED,
          ).tap(&:finalize_binding!)

          # Request OTP
          post auth_app_sign_in_email_url(ri: "jp", fb: @primary_sign_in_binding), params: {
            :user_email => { address: "otp_test@example.com" },
            "cf-turnstile-response" => "test_token",
          }

          email.reload

          assert_not email.attributes.key?("otp_private_key")
          assert_not email.attributes.key?("otp_counter")
        end

        test "sign-in verification consumes ceremony OTP while preserving identifier identity" do
          user = clients(:one)
          # Create existing email
          email = ClientEmail.create!(
            user: user, address: "cleanup_test@example.com", confirm_policy: true,
            user_email_status_id: ClientEmailStatus::VERIFIED,
          ).tap(&:finalize_binding!)

          original_generation = email.attributes.slice(
            "public_id", "address_digest", "number_digest", "user_id",
            "visitor_id", "staff_id",
          )
          perform_enqueued_jobs do
            post auth_app_sign_in_email_url(ri: "jp", fb: @primary_sign_in_binding), params: {
              :user_email => { address: "cleanup_test@example.com" },
              "cf-turnstile-response" => "test_token",
            }
          end
          otp_code = ActionMailer::Base.deliveries
            .last.text_part.body.decoded.match(/Pass Code:\s*([0-9]{6})/).captures.fetch(0)

          travel 31.seconds do
            patch auth_app_sign_in_email_url(ri: "jp", fb: @primary_sign_in_binding), params: {
              user_email: { pass_code: otp_code },
            }
          end

          assert_response :found # Redirects on success

          email.reload

          assert_equal original_generation, email.attributes.slice(*original_generation.keys)
          assert_equal 0, email.otp_attempts_count
        end
      end
    end
  end
end
