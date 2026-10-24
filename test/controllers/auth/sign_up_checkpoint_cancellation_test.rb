# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/oidc_auth_admission_test_helper"

# The resend and cancel endpoints on the sign-up checkpoints. Every checkpoint
# controller routes DELETE to `cancel_from_explicit_step`, and the OTP
# checkpoints additionally route POST to a resend; neither is reachable from the
# happy path, so they are asserted here for the app and corporate surfaces.
class AuthSignUpCheckpointCancellationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include OidcAuthAdmissionTestHelper

  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    Prosopite.pause do
      [1, 2, 3].each { |id| VisitorStatus.find_or_create_by!(id: id) }
      [0, 1, 2, 3].each { |id| VisitorVisibility.find_or_create_by!(id: id) }
      VisitorEmailStatus::DEFAULTS.each { |id| VisitorEmailStatus.find_or_create_by!(id: id) }
    end

    surface = name.to_s.include?("com_") ? "com" : "app"
    bootstrap_auth_sign_in_admission!(surface: surface)
    switch_browser_to_sign_up!(integration_session, surface:, base_browser: @base_browser)
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = @previous_turnstile
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "app email OTP checkpoint reissues the passcode on resend" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    get new_auth_app_sign_up_email_url(ri: "jp", host: host)
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    headers = { "Host" => host,
                "Origin" => "https://#{host}",
                "Sec-Fetch-Site" => "same-origin",
                "X-CSRF-Token" => csrf, }
    post auth_app_sign_up_email_url(ri: "jp", host: host),
         params: {
           user_email: { raw_address: "checkpoint_resend_app@example.com", confirm_policy: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers
    registered = ClientEmail.order(:created_at).last
    first_sent_at = registered.otp_last_sent_at
    original_target = URI.parse(response.location)
    original_binding = Rack::Utils.parse_query(original_target.query).fetch("fb")
    transaction = ClientEmailCeremonyTransaction.find_by!(email_candidate_ref: registered.public_id)
    original_generation = transaction.otp_generation

    decision_time = first_sent_at + EmailOtpPolicy::SEND_COOLDOWN
    ClientEmail.stub(:database_now, decision_time) do
      ClientEmailCeremonyTransaction.stub(:database_now, decision_time) do
        post auth_app_sign_up_check_email_otp_url(ri: "jp", host: host, fb: original_binding), headers: headers
      end
    end

    assert_response :redirect
    assert_not_equal first_sent_at, registered.reload.otp_last_sent_at
    assert_not_equal original_generation, transaction.reload.otp_generation
  end

  test "app email OTP checkpoint cancels the sign-up ceremony on delete" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    get new_auth_app_sign_up_email_url(ri: "jp", host: host)
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    headers = { "Host" => host,
                "Origin" => "https://#{host}",
                "Sec-Fetch-Site" => "same-origin",
                "X-CSRF-Token" => csrf, }
    post auth_app_sign_up_email_url(ri: "jp", host: host),
         params: {
           user_email: { raw_address: "checkpoint_cancel_app@example.com", confirm_policy: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers

    original_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    delete auth_app_sign_up_check_email_otp_url(ri: "jp", host: host, fb: original_binding), headers: headers

    assert_response :redirect
    assert_nil session[:auth_app_up_sequence_id]
  end

  test "com email OTP checkpoint cancels the sign-up ceremony on delete" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host
    get new_auth_com_sign_up_email_url(ri: "jp", host: host)
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    headers = { "Host" => host,
                "Origin" => "https://#{host}",
                "Sec-Fetch-Site" => "same-origin",
                "X-CSRF-Token" => csrf, }
    post auth_com_sign_up_email_url(ri: "jp", host: host),
         params: {
           visitor_email: { raw_address: "checkpoint_cancel_com@example.com", confirm_policy: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers

    original_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    delete auth_com_sign_up_check_email_otp_url(ri: "jp", host: host, fb: original_binding), headers: headers

    assert_response :redirect
    assert_nil session[:auth_com_up_sequence_id]
  end

  test "com email OTP checkpoint reissues the passcode on resend" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host
    get new_auth_com_sign_up_email_url(ri: "jp", host: host)
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    headers = { "Host" => host,
                "Origin" => "https://#{host}",
                "Sec-Fetch-Site" => "same-origin",
                "X-CSRF-Token" => csrf, }
    post auth_com_sign_up_email_url(ri: "jp", host: host),
         params: {
           visitor_email: { raw_address: "checkpoint_resend_com@example.com", confirm_policy: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers
    registered = VisitorEmail.order(:created_at).last
    first_sent_at = registered.otp_last_sent_at
    original_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    transaction = VisitorEmailCeremonyTransaction.find_by!(email_candidate_ref: registered.public_id)
    original_generation = transaction.otp_generation

    decision_time = first_sent_at + EmailOtpPolicy::SEND_COOLDOWN
    VisitorEmail.stub(:database_now, decision_time) do
      VisitorEmailCeremonyTransaction.stub(:database_now, decision_time) do
        post auth_com_sign_up_check_email_otp_url(ri: "jp", host: host, fb: original_binding), headers: headers
      end
    end

    assert_response :redirect
    assert_not_equal first_sent_at, registered.reload.otp_last_sent_at
    assert_not_equal original_generation, transaction.reload.otp_generation
  end

  test "app telephone OTP checkpoint cancels the sign-up ceremony on delete" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    get new_auth_app_sign_up_telephone_url(ri: "jp", host: host)
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    headers = { "Host" => host,
                "Origin" => "https://#{host}",
                "Sec-Fetch-Site" => "same-origin",
                "X-CSRF-Token" => csrf, }
    post auth_app_sign_up_telephone_url(ri: "jp", host: host),
         params: {
           user_telephone: { raw_number: "+819012340101", confirm_policy: "1", confirm_using_mfa: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers

    original_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    delete auth_app_sign_up_check_telephone_otp_url(ri: "jp", host: host, fb: original_binding), headers: headers

    assert_response :redirect
    assert_nil session[:auth_app_up_sequence_id]
  end

  test "com telephone passkey checkpoint cancels the sign-up ceremony on delete" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host
    get new_auth_com_sign_up_telephone_url(ri: "jp", host: host)
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    headers = { "Host" => host,
                "Origin" => "https://#{host}",
                "Sec-Fetch-Site" => "same-origin",
                "X-CSRF-Token" => csrf, }
    post auth_com_sign_up_telephone_url(ri: "jp", host: host),
         params: {
           visitor_telephone: { raw_number: "+819012340102", confirm_policy: "1", confirm_using_mfa: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers
    telephone = VisitorTelephone.order(:created_at).last
    original_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    transaction = VisitorTelephoneCeremonyTransaction.find_by!(telephone_candidate_ref: telephone.public_id)
    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == Outbound::SmsDeliveryJob

        encrypted = entry.fetch(:args).fetch(0).fetch("encrypted_payload")
        OutboundSensitivePayload.decrypt_sms_delivery(encrypted).fetch(:otp_binding)[3] == transaction.transaction_id
      end
    payload = OutboundSensitivePayload.decrypt_sms_delivery(delivery.fetch(:args).fetch(0).fetch("encrypted_payload"))
    patch auth_com_sign_up_check_telephone_otp_url(ri: "jp", host: host, fb: original_binding),
          params: {
            :visitor_telephone => { pass_code: payload.fetch(:otp_code) }, "cf-turnstile-response" => "test",
          }, headers: headers

    assert_predicate transaction.reload.otp_consumed_at, :present?
    get auth_com_sign_up_guard_telephone_url(ri: "jp", host: host, fb: original_binding), headers: headers

    delete auth_com_sign_up_check_telephone_passkey_url(ri: "jp", host: host, fb: original_binding), headers: headers

    assert_response :redirect
    assert_nil session[:auth_com_up_sequence_id]
  end

  test "app telephone passkey checkpoint cancels the sign-up ceremony on delete" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    get new_auth_app_sign_up_telephone_url(ri: "jp", host: host)
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    headers = { "Host" => host,
                "Origin" => "https://#{host}",
                "Sec-Fetch-Site" => "same-origin",
                "X-CSRF-Token" => csrf, }
    post auth_app_sign_up_telephone_url(ri: "jp", host: host),
         params: {
           user_telephone: { raw_number: "+819012340111", confirm_policy: "1", confirm_using_mfa: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers
    registration = session[:user_telephone_registration] || {}
    telephone = ClientTelephone.find_by!(public_id: registration[:public_id] || registration["public_id"])
    original_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    transaction = ClientTelephoneCeremonyTransaction.find_by!(telephone_candidate_ref: telephone.public_id)
    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == Outbound::SmsDeliveryJob

        encrypted = entry.fetch(:args).fetch(0).fetch("encrypted_payload")
        OutboundSensitivePayload.decrypt_sms_delivery(encrypted).fetch(:otp_binding)[3] == transaction.transaction_id
      end
    payload = OutboundSensitivePayload.decrypt_sms_delivery(delivery.fetch(:args).fetch(0).fetch("encrypted_payload"))
    patch auth_app_sign_up_check_telephone_otp_url(ri: "jp", host: host, fb: original_binding),
          params: {
            :user_telephone => { pass_code: payload.fetch(:otp_code) }, "cf-turnstile-response" => "test",
          }, headers: headers

    assert_predicate transaction.reload.otp_consumed_at, :present?
    get auth_app_sign_up_guard_telephone_url(ri: "jp", host: host, fb: original_binding), headers: headers

    delete auth_app_sign_up_check_telephone_passkey_url(ri: "jp", host: host, fb: original_binding), headers: headers

    assert_response :redirect
    assert_nil session[:auth_app_up_sequence_id]
  end
end
