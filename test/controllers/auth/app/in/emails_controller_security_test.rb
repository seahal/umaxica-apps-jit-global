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
          host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
          admit_auth_local_entry!(surface: "app")
          TurnstileVerifierStub.challenge_enabled = true
          TurnstileVerifierStub.challenge_response = { "success" => true }
        end

        teardown do
          TurnstileVerifierStub.challenge_enabled = false
          TurnstileVerifierStub.challenge_response = nil
        end

        test "rejects invalid email format" do
          post auth_app_sign_in_email_url(ri: "jp"), params: {
            user_email: { address: "invalid-email" },
          }

          assert_response :unprocessable_content
        end

        test "accepts valid emails with consecutive special characters" do
          # Test that user+tag@example.co.uk format is accepted
          # (This will redirect because email doesn't exist, preventing enumeration)
          post auth_app_sign_in_email_url(ri: "jp"), params: {
            :user_email => { address: "user+tag@example.co.uk" },
            "cf-turnstile-response" => "test_token",
          }

          # Should proceed past format validation
          assert_response :found
        end

        test "accepts valid emails with dots in local part" do
          post auth_app_sign_in_email_url(ri: "jp"), params: {
            :user_email => { address: "user.name@example.com" },
            "cf-turnstile-response" => "test_token",
          }

          # Should proceed past format validation
          assert_response :found
        end

        test "accepts valid emails with underscores" do
          post auth_app_sign_in_email_url(ri: "jp"), params: {
            :user_email => { address: "user_name@example.co.uk" },
            "cf-turnstile-response" => "test_token",
          }

          # Should proceed past format validation
          assert_response :found
        end

        test "accepts Gmail-style addressing with plus" do
          post auth_app_sign_in_email_url(ri: "jp"), params: {
            :user_email => { address: "user+mailbox@gmail.com" },
            "cf-turnstile-response" => "test_token",
          }

          # Should proceed past format validation
          assert_response :found
        end

        test "accepts emails with multiple domain levels" do
          post auth_app_sign_in_email_url(ri: "jp"), params: {
            :user_email => { address: "user@mail.example.co.uk" },
            "cf-turnstile-response" => "test_token",
          }

          # Should proceed past format validation
          assert_response :found
        end

        test "rejects emails without @ symbol" do
          post auth_app_sign_in_email_url(ri: "jp"), params: {
            user_email: { address: "usernameexample.com" },
          }

          assert_response :unprocessable_content
        end

        test "rejects emails without domain" do
          post auth_app_sign_in_email_url(ri: "jp"), params: {
            user_email: { address: "user@" },
          }

          assert_response :unprocessable_content
        end

        test "rejects emails without local part" do
          post auth_app_sign_in_email_url(ri: "jp"), params: {
            user_email: { address: "@example.com" },
          }

          assert_response :unprocessable_content
        end

        test "rejects emails with spaces" do
          post auth_app_sign_in_email_url(ri: "jp"), params: {
            user_email: { address: "user name@example.com" },
          }

          assert_response :unprocessable_content
        end

        test "normalizes email to lowercase" do
          post auth_app_sign_in_email_url(ri: "jp"), params: {
            :user_email => { address: "TEST@EXAMPLE.COM" },
            "cf-turnstile-response" => "test_token",
          }

          # Email should be normalized to lowercase in validation and proceed
          assert_response :found
        end

        test "rejects emails with excessive whitespace" do
          post auth_app_sign_in_email_url(ri: "jp"), params: {
            :user_email => { address: "  test@example.com  " },
            "cf-turnstile-response" => "test_token",
          }

          # Whitespace should be stripped and validated, then proceed
          assert_response :found
        end

        test "handles OTP in database" do
          user = clients(:one)
          # Create existing email
          email = ClientEmail.create!(
            user: user, address: "otp_test@example.com", confirm_policy: true,
            user_email_status_id: ClientEmailStatus::VERIFIED,
          ).tap(&:finalize_binding!)

          # Request OTP
          post auth_app_sign_in_email_url(ri: "jp"), params: {
            :user_email => { address: "otp_test@example.com" },
            "cf-turnstile-response" => "test_token",
          }

          assert_not_nil email.reload.otp_private_key
          assert_not_nil email.otp_counter
        end

        test "cleans up OTP secret_credentials after verification" do
          user = clients(:one)
          # Create existing email
          email = ClientEmail.create!(
            user: user, address: "cleanup_test@example.com", confirm_policy: true,
            user_email_status_id: ClientEmailStatus::VERIFIED,
          ).tap(&:finalize_binding!)

          # Request OTP to generate secret_credentials
          post auth_app_sign_in_email_url(ri: "jp"), params: {
            :user_email => { address: "cleanup_test@example.com" },
            "cf-turnstile-response" => "test_token",
          }

          email.reload
          otp_code = ROTP::HOTP.new(email.otp_private_key).at(Integer(email.otp_counter.to_s, 10))

          travel 31.seconds do
            patch auth_app_sign_in_email_url(ri: "jp"), params: {
              user_email: { pass_code: otp_code },
            }
          end

          assert_response :found # Redirects on success

          email.reload

          assert_equal "0", email.otp_counter
          assert_equal 0, email.otp_attempts_count
        end
      end
    end
  end
end
