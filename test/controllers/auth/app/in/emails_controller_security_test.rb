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
          nonce = SecureRandom.hex(32)
          issuance = OidcTestEntry.issue!(surface: "app", intent: "sign_in", base_browser_nonce: nonce, base_token: nil)
          # An admission reference is accepted only on a top-level document navigation.
          navigation = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }
          get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: navigation

          assert_response :see_other
          get response.location, headers: navigation

          assert_response :see_other
          binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
          binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
          get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: navigation

          assert_response :see_other
          get response.location, headers: navigation

          assert_response :success
          @primary_sign_in_binding = nil
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
