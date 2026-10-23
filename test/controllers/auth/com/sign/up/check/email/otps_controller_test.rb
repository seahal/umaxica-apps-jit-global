# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::Sign::Up::Check::Email::OtpsControllerTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  setup do
    VisitorSignInFlowState::DEFAULTS.each { |id| VisitorSignInFlowState.find_or_create_by!(id: id) }
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    Rails.configuration.x.rate_limit.fetch(:store).clear
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    browser = self
    base_host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    auth_host = @host
    browser.host!(base_host)
    browser.https!
    browser.get("/sign", params: { ri: "jp" })
    csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    browser.post(
      "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: {
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      },
    )
    issuer = JitSecurityJwtRegistry.surface("BASE_COM")
    2.times do |index|
      target = URI.parse(browser.response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless target.host == base_host
        rt = Rack::Utils.parse_query(target.query).fetch("rt")
        payload, = JWT.decode(
          rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        target = URI.parse(payload.fetch("url"))
      end

      assert_includes [base_host, auth_host], target.host
      browser.host!(target.host)
      browser.get(target.request_uri, params: { ri: "jp" })
      next if index == 1

      form = browser.response.parsed_body.at_css("form#base-authorization-ceremony-start-form")
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      browser.post(
        form["action"], params: fields, headers: {
          "Origin" => "https://#{target.host}", "Sec-Fetch-Site" => "same-origin",
        },
      )
    end
    # Redeem through Auth POST, Base confirmation POST, then Auth POST.
    # No admission, browser marker or signed flow locator is installed directly.
    3.times do |index|
      form = browser.response.parsed_body.at_css("form")

      assert_not_nil form, "admission step #{index}, HTTP #{browser.response.status}"
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      browser.post(
        form["action"], params: fields, headers: {
          "Origin" => "https://#{browser.host}", "Sec-Fetch-Site" => "same-origin",
        },
      )
      break if index == 2

      target = URI.parse(browser.response.location)

      assert_includes [base_host, auth_host], target.host
      browser.host!(target.host)
      browser.get(target.request_uri, params: { ri: "jp" })
    end

    assert_equal 303, browser.response.status
    switch_browser_to_sign_up!(browser, surface: "com")
    browser.get("/sign/up/email/new", params: { ri: "jp" })

    assert_equal 200, browser.response.status
    csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    @headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "get show renders the otp form with a visible Turnstile challenge" do
    clear_enqueued_jobs
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "com-email-show@example.com",
                                       confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))
    visitor_email = VisitorEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = VisitorEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == visitor_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == visitor_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(visitor_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"

    assert_not visitor_email.attributes.values.include?(otp_code), "Source must not hold the random OTP code"
    assert_not visitor_email.attributes.values.include?(transaction.otp_verifier),
               "Source must not hold the keyed proof"
    transaction = VisitorEmailCeremonyTransaction.where(
      operation: "sign_up",
      email_candidate_ref: visitor_email.public_id,
    ).sole

    assert_equal "sign_up", transaction.purpose
    assert_predicate transaction.otp_verifier, :present?

    get auth_com_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding), headers: @headers

    assert_response :success
    assert_equal "auth/com/sign/up/emails/edit",
                 JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("component")
    assert_equal "render",
                 JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
                   .fetch("turnstile").fetch("mode")
    assert_predicate JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
      .fetch("turnstile").fetch("site_key"),
                     :present?
    assert_predicate JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
      .fetch("turnstile").fetch("challenge_id"),
                     :present?
  end

  test "patch with a valid otp and missing, invalid, or unavailable Turnstile does not consume the otp" do
    clear_enqueued_jobs
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "com-email-turnstile@example.com",
                                       confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))
    visitor_email = VisitorEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = VisitorEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == visitor_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == visitor_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(visitor_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"
    cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))
    attempts_before = visitor_email.reload.otp_attempts_count
    proof_before = transaction.attributes
    [
      [nil, { "success" => false }],
      ["invalid-turnstile-token", { "success" => false }],
      ["provider-outage-token", { "success" => false, "unavailable" => true }],
    ].each do |turnstile_token, verification_result|
      TurnstileVerifierStub.challenge_response = verification_result
      params = { visitor_email: { pass_code: otp_code } }
      params["cf-turnstile-response"] = turnstile_token if turnstile_token

      patch auth_com_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding), params: params, headers: @headers

      assert_response :unprocessable_content
      assert_equal "render",
                   JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
                     .fetch("turnstile").fetch("mode")
    end

    assert_equal attempts_before, visitor_email.reload.otp_attempts_count
    assert_withheld("Turnstile refusal must preserve the entire live OTP proof") {
      proof_before == transaction.reload.attributes
    }
    assert_equal VisitorSignUpFlowStatus::CONTACT_PENDING, cycle.reload.status_id
    assert_nil cycle.completed_requirements["otp"]
  end

  test "degraded Turnstile accepts only upstream-unavailable results" do
    clear_enqueued_jobs
    post(
      auth_com_sign_up_email_url(ri: "jp"),
      params: { :visitor_email => { raw_address: "com-email-degraded@example.com",
                                    confirm_policy: "1", },
                "cf-turnstile-response" => "test", },
      headers: @headers,
    )

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))
    visitor_email = VisitorEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = VisitorEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == visitor_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == visitor_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(visitor_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"
    attempts_before = visitor_email.reload.otp_attempts_count
    proof_before = transaction.attributes
    Flipper.enable(:turnstile_degraded_mode)

    TurnstileVerifierStub.challenge_response = { "success" => false }
    patch(
      auth_com_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
      params: {
        "visitor_email" => { "pass_code" => otp_code },
        "cf-turnstile-response" => "invalid-turnstile-token",
      },
      headers: @headers,
    )

    assert_response :unprocessable_content
    assert_equal attempts_before, visitor_email.reload.otp_attempts_count
    assert_withheld("Turnstile refusal must preserve the entire live OTP proof") {
      proof_before == transaction.reload.attributes
    }
    TurnstileVerifierStub.challenge_response = { "success" => false, "unavailable" => true }
    patch(
      auth_com_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
      params: {
        "visitor_email" => { "pass_code" => otp_code },
        "cf-turnstile-response" => "provider-outage-token",
      },
      headers: @headers,
    )

    assert_response :redirect
  ensure
    Flipper.disable(:turnstile_degraded_mode)
  end

  test "patch with a valid otp advances to the birthdate checkpoint" do
    clear_enqueued_jobs
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "com-email-valid@example.com",
                                       confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))
    visitor_email = VisitorEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = VisitorEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == visitor_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == visitor_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(visitor_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"
    cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))

    assert_equal VisitorSignUpFlowStatus::CONTACT_PENDING, cycle.status_id
    assert_equal 0, cycle.checkpoint_version

    patch auth_com_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
          params: {
            "visitor_email" => { "pass_code" => otp_code },
            "cf-turnstile-response" => "valid-turnstile-token",
          },
          headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    assert_redirected_to auth_com_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
    assert_equal VisitorEmailStatus::VERIFIED_WITH_SIGN_UP, visitor_email.reload.visitor_email_status_id
    assert_equal VisitorSignUpFlowStatus::CHECKPOINT_PENDING, cycle.reload.status_id
    assert_equal "checkpoint", cycle.step
    assert cycle.completed_requirements.dig("otp", "cleared")
    assert_predicate cycle.completed_requirements.dig("otp", "cleared_at"), :present?
  end

  test "clearing the otp requirement increments the checkpoint version" do
    clear_enqueued_jobs
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "com-email-version@example.com",
                                       confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))
    visitor_email = VisitorEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = VisitorEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == visitor_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == visitor_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(visitor_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"
    cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))

    patch auth_com_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
          params: { :visitor_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
          headers: @headers

    # The requirement is cleared through the state machine rather than by
    # writing completed_requirements directly, so the stale-checkpoint guard
    # for every later step becomes effective from here on.
    assert_equal 1, cycle.reload.checkpoint_version
  end

  test "patch with a blank otp returns a validation error" do
    clear_enqueued_jobs
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "com-email-blank@example.com",
                                       confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))
    email = VisitorEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = VisitorEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"

    patch auth_com_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
          params: { :visitor_email => { pass_code: "" }, "cf-turnstile-response" => "test" },
          headers: @headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.update.code_required")
  end

  test "patch with an invalid otp leaves the ticket at contact pending" do
    clear_enqueued_jobs
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "com-email-wrong@example.com",
                                       confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))
    email = VisitorEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = VisitorEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"
    cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))

    patch auth_com_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
          params: { :visitor_email => { pass_code: ((otp_code == "000000") ? "000001" : "000000") },
                    "cf-turnstile-response" => "test", },
          headers: @headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.update.invalid_code")
    assert_equal VisitorSignUpFlowStatus::CONTACT_PENDING, cycle.reload.status_id
    assert_nil cycle.completed_requirements["otp"]
    assert_equal 0, cycle.checkpoint_version
  end

  test "patch with repeated invalid otp attempts locks the flow" do
    clear_enqueued_jobs
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "com-email-lock@example.com",
                                       confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))
    visitor_email = VisitorEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = VisitorEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == visitor_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == visitor_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(visitor_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"
    cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))

    EmailOtpPolicy::MAX_OTP_ATTEMPTS.times do
      patch auth_com_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
            params: { :visitor_email => { pass_code: ((otp_code == "000000") ? "000001" : "000000") },
                      "cf-turnstile-response" => "test", },
            headers: @headers
    end

    assert_response :too_many_requests
    assert_includes response.body, I18n.t("sign.app.registration.email.update.attempts_exceeded")
    assert_predicate visitor_email.reload, :locked?
    assert_nil cycle.reload.completed_requirements["otp"]
  end

  test "wrong OTP for an independently held destination does not advance its candidate or change the owner" do
    VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    owner = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
    )
    existing = VisitorEmail.create!(
      visitor_id: owner.id, address: "com-email-existing@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    existing.finalize_binding!

    clear_enqueued_jobs
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "com-email-existing@example.com",
                                       confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))
    email = VisitorEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = VisitorEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"

    cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))

    assert_equal VisitorSignUpFlowStatus::CONTACT_PENDING, cycle.status_id
    candidate = VisitorEmail.find(cycle.pending_contact_id)

    assert_not_equal existing.visitor_id, candidate.visitor_id
    assert_nil candidate.binding_finalized_at

    patch auth_com_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
          params: { :visitor_email => { pass_code: ((otp_code == "000000") ? "000001" : "000000") },
                    "cf-turnstile-response" => "test", },
          headers: @headers

    # A competing candidate owns its own real proof and cannot mutate the effective owner.
    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.update.invalid_code")
    assert_equal VisitorEmailStatus::VERIFIED, existing.reload.visitor_email_status_id
    assert_equal VisitorSignUpFlowStatus::CONTACT_PENDING, cycle.reload.status_id
    assert_nil cycle.completed_requirements["otp"]
    assert_predicate existing.reload, :binding_effective?
    assert_nil candidate.reload.binding_finalized_at
  end
end
