# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::Up::Check::Email::OtpsControllerTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  self.fixture_table_names = []

  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers
  include SignInFlowCleanup

  setup do
    # The test lock serializes these HTTP journeys; retain pre-existing rows for scoped cleanup.
    @initial_client_ids = Client.pluck(:id)
    @initial_signup_ids = ClientSignUpFlow.pluck(:id)
    @initial_binding_ids = ClientAuthAdmissionBinding.pluck(:id)
    @initial_ceremony_ids = ClientAuthCeremonySession.pluck(:id)
    @initial_parent_ids = ClientOidcAuthorizationTransaction.pluck(:id)
    ClientSignInFlowState::DEFAULTS.each { |id| ClientSignInFlowState.find_or_create_by!(id: id) }
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    Rails.configuration.x.rate_limit.fetch(:store).clear
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    browser = self
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
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
    12.times do
      break unless browser.response.redirect?

      target = URI.parse(browser.response.location)
      if target.host == "jump.umaxica.net"
        token = Rack::Utils.parse_query(target.query).fetch("rt")
        payload, = JWT.decode(token, nil, false)
        target = URI.parse(payload.fetch("url"))
      end

      assert_includes [base_host, visa_host_for_test_base_host(base_host), auth_host], target.host
      browser.host!(target.host)
      browser.get(target.request_uri, headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" })
    end

    assert_equal 200, browser.response.status
    assert_equal auth_host, browser.host
    switch_browser_to_sign_up!(browser)
    browser.get("/sign/up/email/new", params: { ri: "jp" })

    assert_equal 200, browser.response.status
    csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    @headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf }
  end

  teardown do
    # Delivery runs after real commits, so rollback fixtures cannot clean up this journey.
    owners = Client.where.not(id: @initial_client_ids).to_a
    owner_ids = owners.map(&:id)
    # Completed signup also commits the actor's bootstrap identity and collective graph.
    owners.each do |owner|
      identity_ids = ClientIdentity.where(source_record_id: owner.id).pluck(:id)
      persona_ids = ClientPersona.where(client_identity_id: identity_ids).pluck(:id)
      enterprise_ids =
        (PersonaMembership.where(persona_id: persona_ids).pluck(:enterprise_id) +
          EnterpriseOwnership.where(client_id: owner.id).pluck(:enterprise_id)).uniq
      unit_ids = EnterpriseUnit.where(enterprise_id: enterprise_ids).pluck(:id)
      PersonaMembership.where(persona_id: persona_ids)
        .or(PersonaMembership.where(enterprise_id: enterprise_ids)).delete_all
      PersonaAssignment.where(persona_id: persona_ids).delete_all
      ClientOidcIdentityBinding.where(client_identity_id: identity_ids).delete_all
      AvatarPersonaBinding.where(persona_id: persona_ids).delete_all
      ClientPersonaOwnership.where(client_persona_id: persona_ids).delete_all
      ClientPersonaLifecycle.where(client_persona_id: persona_ids).delete_all
      ClientPersona.where(id: persona_ids).delete_all
      ClientIdentity.where(id: identity_ids).delete_all
      EnterpriseUnitClosure.where(ancestor_id: unit_ids)
        .or(EnterpriseUnitClosure.where(descendant_id: unit_ids)).delete_all
      EnterpriseUnit.where(id: unit_ids).delete_all
      EnterpriseLifecycle.where(enterprise_id: enterprise_ids).delete_all
      EnterpriseOwnership.where(enterprise_id: enterprise_ids).delete_all
      EnterpriseAdministrationGrant.where(enterprise_id: enterprise_ids).delete_all
      EnterpriseDelegationGrant.where(enterprise_id: enterprise_ids).delete_all
      EnterpriseViewGrant.where(enterprise_id: enterprise_ids).delete_all
      EnterpriseOwnershipTransferRequest.where(enterprise_id: enterprise_ids).delete_all
      Enterprise.where(id: enterprise_ids).delete_all
    end
    flows = ClientSignUpFlow.where.not(id: @initial_signup_ids).to_a
    session_refs =
      flows.map do |flow|
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", flow.public_id, flow.nonce_digest]))
      end
    ClientEmailCeremonyTransaction.where(session_ref: session_refs).delete_all
    ClientSignUpFlow.where(id: flows.map(&:id)).delete_all
    ClientAuthAdmissionBinding.where.not(id: @initial_binding_ids).delete_all
    ClientAuthCeremonySession.where.not(id: @initial_ceremony_ids).delete_all
    ClientOidcAuthorizationTransaction.where.not(id: @initial_parent_ids).delete_all
    delete_client_sign_in_flows!(ClientSignInFlow.where(principal_id: owner_ids))
    ClientDeviceSession.where(user_id: owner_ids).update_all(current_refresh_token_id: nil)
    ClientToken.where(user_id: owner_ids).delete_all
    ClientDeviceSession.where(user_id: owner_ids).delete_all
    ClientContactAuditOutbox.where(owner_ref: owners.map(&:public_id)).delete_all
    ClientEmail.where(user_id: owner_ids).delete_all
    ClientAccount.where(user_id: owner_ids).delete_all
    ClientOidcConnection.where(user_id: owner_ids).delete_all
    ClientRegistrationCompletion.where(client_id: owner_ids).delete_all
    ClientAuthorityLock.where(client_id: owner_ids).delete_all
    Client.where(id: owner_ids).delete_all
  ensure
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "show renders the otp form" do
    clear_enqueued_jobs
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :client_email => { raw_address: "email-show@example.com",
                                      confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    user_email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == user_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == user_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(user_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"

    assert_not user_email.attributes.values.include?(otp_code), "Source must not hold the random OTP code"
    assert_not user_email.attributes.values.include?(transaction.otp_verifier), "Source must not hold the keyed proof"
    transaction = ClientEmailCeremonyTransaction.where(
      operation: "sign_up",
      email_candidate_ref: user_email.public_id,
    ).sole

    assert_equal "sign_up", transaction.purpose
    assert_predicate transaction.otp_verifier, :present?

    get auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding), headers: @headers

    assert_response :success
    assert_equal "auth/app/sign/up/emails/edit",
                 JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("component")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_equal I18n.t("sign.app.authentication.email.edit.page_title"), props.fetch("title")
    assert_equal I18n.t("sign.app.authentication.email.edit.code_label"), props.fetch("code_label")
    assert_equal I18n.t("sign.app.authentication.email.edit.submit"), props.fetch("submit_label")
    assert_equal "render", props.fetch("turnstile").fetch("mode")
    assert_predicate props.fetch("turnstile").fetch("site_key"), :present?
    assert_predicate props.fetch("turnstile").fetch("challenge_id"), :present?
  end

  test "patch with a valid otp and missing, invalid, or unavailable Turnstile does not consume the otp" do
    clear_enqueued_jobs
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :client_email => { raw_address: "email-turnstile@example.com",
                                      confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    user_email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == user_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == user_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(user_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    attempts_before = user_email.reload.otp_attempts_count
    proof_before = transaction.attributes
    [
      [nil, { "success" => false }],
      ["invalid-turnstile-token", { "success" => false }],
      ["provider-outage-token", { "success" => false, "unavailable" => true }],
    ].each do |turnstile_token, verification_result|
      TurnstileVerifierStub.challenge_response = verification_result
      params = { client_email: { pass_code: otp_code } }
      params["cf-turnstile-response"] = turnstile_token if turnstile_token

      patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding), params: params, headers: @headers

      assert_response :unprocessable_content
      assert_equal "render",
                   JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
                     .fetch("turnstile").fetch("mode")
    end

    assert_equal attempts_before, user_email.reload.otp_attempts_count
    assert_withheld("Turnstile refusal must preserve the entire live OTP proof") {
      proof_before == transaction.reload.attributes
    }
    assert_equal ClientSignUpFlowStatus::CONTACT_PENDING, cycle.reload.status_id
    assert_nil cycle.completed_requirements["otp"]
  end

  test "degraded Turnstile accepts only upstream-unavailable results and never re-renders the otp" do
    clear_enqueued_jobs
    post(
      auth_app_sign_up_email_url(ri: "jp"),
      params: { :client_email => { raw_address: "email-degraded@example.com",
                                   confirm_policy: "1", },
                "cf-turnstile-response" => "test", },
      headers: @headers,
    )

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    user_email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == user_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == user_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(user_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    attempts_before = user_email.reload.otp_attempts_count
    proof_before = transaction.attributes
    Flipper.enable(:turnstile_degraded_mode)

    TurnstileVerifierStub.challenge_response = { "success" => false }
    patch(
      auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
      params: {
        "client_email" => { "pass_code" => otp_code },
        "cf-turnstile-response" => "invalid-turnstile-token",
      },
      headers: @headers,
    )

    assert_response :unprocessable_content
    assert_not_includes response.body, otp_code
    assert_equal attempts_before, user_email.reload.otp_attempts_count
    assert_withheld("Turnstile refusal must preserve the entire live OTP proof") {
      proof_before == transaction.reload.attributes
    }
    TurnstileVerifierStub.challenge_response = { "success" => false, "unavailable" => true }
    patch(
      auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
      params: {
        "client_email" => { "pass_code" => otp_code },
        "cf-turnstile-response" => "provider-outage-token",
      },
      headers: @headers,
    )

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    assert_redirected_to auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
    assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, cycle.reload.status_id
  ensure
    Flipper.disable(:turnstile_degraded_mode)
  end

  test "patch with a valid otp advances to the birthdate checkpoint" do
    clear_enqueued_jobs
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :client_email => { raw_address: "email-valid@example.com",
                                      confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    user_email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == user_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == user_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(user_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))

    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
          params: {
            "client_email" => { "pass_code" => otp_code },
            "cf-turnstile-response" => "valid-turnstile-token",
          },
          headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    assert_redirected_to auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
    assert_equal ClientEmailStatus::VERIFIED_WITH_SIGN_UP, user_email.reload.user_email_status_id
    assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, cycle.reload.status_id
    assert_equal "checkpoint", cycle.reload.step
    assert cycle.reload.completed_requirements.dig("otp", "cleared")
    assert_predicate cycle.reload.completed_requirements.dig("otp", "cleared_at"), :present?
  end

  # Control the owning Ticket clock without advancing the browser wall clock: advancing both
  # also switches GETs to the separate replica fixture database after the resolver delay.
  test "show with an expired otp redirects to the start" do
    clear_enqueued_jobs
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :client_email => { raw_address: "email-show-expired@example.com",
                                      confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    user_email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == user_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == user_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(user_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"

    expiry = ClientEmailCeremonyTransaction.where(
      operation: "sign_up",
      email_candidate_ref: user_email.public_id,
    ).sole.otp_expires_at
    ClientEmailCeremonyTransaction.stub(:database_now, expiry + 1.second) do
      get auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding), headers: @headers
    end

    assert_response :redirect
    assert_redirected_to new_auth_app_sign_up_email_url(ri: "jp")
  end

  test "show at the exact independent Email OTP deadline redirects to the start" do
    clear_enqueued_jobs
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :client_email => { raw_address: "email-show-exact-expiry@example.com",
                                      confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    user_email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == user_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == user_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(user_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"

    expiry = ClientEmailCeremonyTransaction.where(
      operation: "sign_up",
      email_candidate_ref: user_email.public_id,
    ).sole.otp_expires_at
    ClientEmailCeremonyTransaction.stub(:database_now, expiry) do
      get auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding), headers: @headers
    end

    assert_response :redirect
    assert_redirected_to new_auth_app_sign_up_email_url(ri: "jp")
  end

  test "show one second before the independent Email OTP deadline remains available" do
    clear_enqueued_jobs
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :client_email => { raw_address: "email-show-before-expiry@example.com",
                                      confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    user_email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == user_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == user_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(user_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"

    expiry = ClientEmailCeremonyTransaction.where(
      operation: "sign_up",
      email_candidate_ref: user_email.public_id,
    ).sole.otp_expires_at
    ClientEmailCeremonyTransaction.stub(:database_now, expiry - 1.second) do
      get auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding), headers: @headers
    end

    assert_response :success
    assert_nil transaction.reload.otp_consumed_at
  end

  test "patch with an expired otp redirects to the start" do
    clear_enqueued_jobs
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :client_email => { raw_address: "email-expired@example.com",
                                      confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    user_email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == user_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == user_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(user_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"

    expiry = ClientEmailCeremonyTransaction.where(
      operation: "sign_up",
      email_candidate_ref: user_email.public_id,
    ).sole.otp_expires_at
    ClientEmailCeremonyTransaction.stub(:database_now, expiry + 1.second) do
      patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
            params: { :client_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
            headers: @headers
    end

    assert_response :redirect
    assert_redirected_to new_auth_app_sign_up_email_url(ri: "jp")
  end

  test "patch at the exact independent Email OTP deadline refuses even the delivered correct code" do
    clear_enqueued_jobs
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :client_email => { raw_address: "email-exact-expiry@example.com",
                                      confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    user_email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == user_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == user_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(user_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"

    expiry = ClientEmailCeremonyTransaction.where(
      operation: "sign_up",
      email_candidate_ref: user_email.public_id,
    ).sole.otp_expires_at
    ClientEmailCeremonyTransaction.stub(:database_now, expiry) do
      patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
            params: { :client_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
            headers: @headers
    end

    assert_response :redirect
    assert_redirected_to new_auth_app_sign_up_email_url(ri: "jp")
    assert_nil transaction.reload.otp_consumed_at
  end

  test "patch one second before the independent Email OTP deadline consumes the delivered code" do
    clear_enqueued_jobs
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :client_email => { raw_address: "email-before-expiry@example.com",
                                      confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    user_email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == user_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == user_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(user_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"

    expiry = ClientEmailCeremonyTransaction.where(
      operation: "sign_up",
      email_candidate_ref: user_email.public_id,
    ).sole.otp_expires_at
    ClientEmailCeremonyTransaction.stub(:database_now, expiry - 1.second) do
      patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
            params: { :client_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
            headers: @headers
    end

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    assert_redirected_to auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
    assert_not_nil transaction.reload.otp_consumed_at
    assert_nil transaction.otp_verifier
    assert_not_nil transaction.otp_receipt_verifier
  end

  test "patch with a blank otp returns a validation error" do
    clear_enqueued_jobs
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :client_email => { raw_address: "email-blank@example.com",
                                      confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
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

    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
          params: { :client_email => { pass_code: "" }, "cf-turnstile-response" => "test" },
          headers: @headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.update.code_required")
  end

  test "patch with an invalid otp returns a validation error" do
    clear_enqueued_jobs
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :client_email => { raw_address: "email-wrong@example.com",
                                      confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
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

    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
          params: { :client_email => { pass_code: ((otp_code == "000000") ? "000001" : "000000") },
                    "cf-turnstile-response" => "test", },
          headers: @headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.update.invalid_code")
  end

  test "resend rotates the email code and registered destinations keep the same response" do
    clear_enqueued_jobs
    address = "email-resend-#{SecureRandom.hex(8)}@example.test"
    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           :client_email => { raw_address: address, confirm_policy: "1" },
           "cf-turnstile-response" => "test",
         }, headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    email = ClientEmail.find(cycle.pending_contact_id)
    transaction = ClientEmailCeremonyTransaction.find_by!(email_candidate_ref: email.public_id)
    initial_job = enqueued_jobs.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }
    initial_delivery = ActiveJob::Arguments.deserialize(initial_job.fetch(:args)).last.fetch(:params)
    old_code = OutboundSensitivePayload.decrypt_email_otp(initial_delivery.fetch(:encrypted_hotp_token))
    initial_generation = transaction.otp_generation

    get auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding), headers: @headers

    assert_response :success
    resend = inertia_props.fetch("otp_resend")

    assert_equal @flow_binding, resend.fetch("state")
    resend_uri = URI.parse(resend.fetch("endpoint"))

    assert_equal auth_app_sign_up_check_email_otp_path, resend_uri.path
    assert_equal @flow_binding, Rack::Utils.parse_query(resend_uri.query).fetch("fb")
    initial_delivery_count = enqueued_jobs.count { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    post resend.fetch("endpoint"), params: { state: resend.fetch("state") }, as: :json, headers: @headers

    assert_response :too_many_requests
    cooldown_retry_after = response.parsed_body.fetch("retry_after")

    assert_operator cooldown_retry_after, :>, 0
    assert_equal initial_delivery_count,
                 enqueued_jobs.count { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    resend_at = email.otp_last_sent_at + EmailOtpPolicy::SEND_COOLDOWN + 1.second
    ClientEmail.stub(:database_now, resend_at) do
      post resend.fetch("endpoint"), params: { state: resend.fetch("state") }, as: :json, headers: @headers
    end

    assert_response :success
    assert_equal({ "resendable" => true, "retry_after" => 0 }, response.parsed_body)
    assert_equal initial_delivery_count + 1,
                 enqueued_jobs.count { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }
    assert_not_equal initial_generation, transaction.reload.otp_generation
    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
          params: { :client_email => { pass_code: old_code }, "cf-turnstile-response" => "test" }, headers: @headers

    assert_response :unprocessable_content
    wrong_props = inertia_props

    assert_equal [I18n.t("sign.app.registration.email.update.invalid_code")], wrong_props.fetch("errors")
    assert_equal "auth/app/sign/up/emails/edit", inertia_component
    assert_equal "client_email", wrong_props.fetch("scope")
    wrong_headers = response.headers.slice("Cache-Control", "Content-Type", "Vary")

    competitor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::VERIFIED_WITH_SIGN_UP,
    )
    registered = competitor.client_emails.create!(
      raw_address: address,
      confirm_policy: true,
      user_email_status_id: ClientEmailStatus::VERIFIED,
      binding_finalized_at: ClientEmail.database_now,
    )
    row_facts = [email.reload.attributes, cycle.reload.attributes, contact_owner_for_test(email).reload.attributes,
                 competitor.reload.attributes, registered.reload.attributes,]
    delivery_count_before_registered_code =
      enqueued_jobs.count { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
          params: { :client_email => { pass_code: "123456" }, "cf-turnstile-response" => "test" }, headers: @headers

    assert_response :unprocessable_content
    registered_props = inertia_props

    assert_equal [I18n.t("sign.app.registration.email.update.invalid_code")], registered_props.fetch("errors")
    assert_equal wrong_props.fetch("errors"), registered_props.fetch("errors")
    assert_equal "auth/app/sign/up/emails/edit", inertia_component
    assert_equal "client_email", registered_props.fetch("scope")
    assert_equal wrong_headers, response.headers.slice("Cache-Control", "Content-Type", "Vary")
    assert_equal row_facts,
                 [email.reload.attributes, cycle.reload.attributes, contact_owner_for_test(email).reload.attributes,
                  competitor.reload.attributes, registered.reload.attributes,]
    assert_equal delivery_count_before_registered_code,
                 enqueued_jobs.count { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    post auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
         params: { state: resend.fetch("state") }, as: :json, headers: @headers

    assert_response :too_many_requests
    assert_not response.parsed_body.fetch("resendable")
    assert_operator response.parsed_body.fetch("retry_after"), :>, 0
    assert_equal delivery_count_before_registered_code,
                 enqueued_jobs.count { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }
  end

  test "resending an email code rejects the old code and accepts the new code" do
    clear_enqueued_jobs
    address = "email-resend-accepted-#{SecureRandom.hex(8)}@example.test"
    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           :client_email => { raw_address: address, confirm_policy: "1" },
           "cf-turnstile-response" => "test",
         }, headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    email = ClientEmail.find(cycle.pending_contact_id)
    initial_job = enqueued_jobs.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }
    initial_delivery = ActiveJob::Arguments.deserialize(initial_job.fetch(:args)).last.fetch(:params)
    old_code = OutboundSensitivePayload.decrypt_email_otp(initial_delivery.fetch(:encrypted_hotp_token))

    get auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding), headers: @headers

    assert_response :success
    resend = inertia_props.fetch("otp_resend")
    resend_at = email.otp_last_sent_at + EmailOtpPolicy::SEND_COOLDOWN + 1.second
    ClientEmail.stub(:database_now, resend_at) do
      post resend.fetch("endpoint"), params: { state: resend.fetch("state") }, as: :json, headers: @headers
    end

    assert_response :success
    resent_job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }
    resent_delivery = ActiveJob::Arguments.deserialize(resent_job.fetch(:args)).last.fetch(:params)
    new_code = OutboundSensitivePayload.decrypt_email_otp(resent_delivery.fetch(:encrypted_hotp_token))

    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
          params: { :client_email => { pass_code: old_code }, "cf-turnstile-response" => "test" }, headers: @headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.update.invalid_code")

    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
          params: { :client_email => { pass_code: new_code }, "cf-turnstile-response" => "test" }, headers: @headers

    assert_response :redirect
  end

  test "patch with repeated invalid otp attempts locks the flow" do
    clear_enqueued_jobs
    post auth_app_sign_up_email_url(ri: "jp"),
         params: { :client_email => { raw_address: "email-lock@example.com",
                                      confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    user_email = ClientEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == user_email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == user_email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == contact_owner_for_test(user_email).public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"
    cycle = ClientSignUpFlow.find_by!(public_id: session.fetch(:auth_app_up_sequence_id))
    completed_requirements = cycle.completed_requirements.deep_dup

    EmailOtpPolicy::MAX_OTP_ATTEMPTS.times do
      patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
            params: { :client_email => { pass_code: ((otp_code == "000000") ? "000001" : "000000") },
                      "cf-turnstile-response" => "test", },
            headers: @headers
    end

    assert_response :too_many_requests
    assert_includes response.body, I18n.t("sign.app.registration.email.update.attempts_exceeded")
    assert_predicate user_email.reload, :locked?
    assert_equal "init", session[SignEmailRegistrable::SESSION_KEY]
    assert_equal completed_requirements, cycle.reload.completed_requirements
    assert_nil cycle.reload.completed_requirements["otp"]
  end
end

# DAMP local helper copy for former shared test support.
class Auth::App::Sign::Up::Check::Email::OtpsControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
    )
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :app),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    else "step_up:app"
    end
  end

  def signed_step_up_pt_for(path, surface:, session_nonce:)
    safe_path = path.to_s
    return nil if safe_path.blank? || !safe_path.start_with?("/") || safe_path.match?(/[\x00-\x1F\x7F]/)

    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256",
      serializer: JSON,
      url_safe: true,
    )
    verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => surface.to_s,
        "session_nonce" => session_nonce.to_s,
        "pt" => safe_path, },
      purpose: :path_target,
      expires_in: 15.minutes,
    )
  end

  def signed_step_up_grant_for(actor:, token:, scope:, return_to:, surface:, methods: %i(email_otp totp passkey),
                               aal: "aal2")
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface.to_s,
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      required_scope: scope.to_s,
      required_aal: aal,
      allowed_methods: methods,
      return_to: return_to,
      expires_at: 15.minutes.from_now,
    ).grant
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def csrf_headers(token)
    { "X-CSRF-Token" => token }
  end

  def fetch_csrf_token(path)
    get(path)
    response.body[/name="authenticity_token" value="([^"]+)"/, 1] || response.body
  end

  def social_callback_headers(host)
    scheme = host.to_s.include?("localhost") ? "http" : "https"
    origin = "#{scheme}://#{host}"
    cookies["csrf_token"] = csrf_token_value if respond_to?(:cookies)
    {
      "Host" => host,
      "Origin" => origin,
      "Referer" => "#{origin}/",
      "Sec-Fetch-Site" => "same-origin",
      "X-STRICT-SOCIAL-STATE" => "1",
      "X-CSRF-Token" => csrf_token_value,
    }
  end

  def social_auth_state_from_response
    session[:social_auth_state].presence || begin
      uri = URI.parse(response.location.to_s)
      Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
    rescue URI::InvalidURIError
      nil
    end
  end

  def seed_social_auth_session(provider:, intent: "login", user: nil, entry: nil, ri: "jp", rt: nil, referer: nil)
    host = configured_host(:sign_service)
    host!(host) if respond_to?(:host!)
    normalized_provider = SocialIdentifiable.normalize_provider(provider)
    continue_path =
      if intent.to_s == "link"
        public_send(:"auth_app_settings_#{normalized_provider}_path", ri: ri)
      elsif entry.to_s == "sign_up"
        public_send(:"auth_app_social_#{normalized_provider}_registration_path", ri: ri, rt: rt)
      else
        public_send(:"auth_app_social_#{normalized_provider}_session_path", ri: ri, rt: rt)
      end
    headers = social_callback_headers(host)
    headers["Referer"] = referer if referer.present?
    if user
      user_headers = as_user_headers(user, host: host)
      token = ClientToken.find_by(public_id: user_headers["X-TEST-SESSION-PUBLIC-ID"])
      mark_token_step_up_satisfied_for_test(
        token,
        scope: SocialAuth::SOCIAL_LINK_SCOPE,
      ) if intent.to_s == "link" && token
      headers = headers.merge(user_headers)
    end
    post(continue_path, headers: headers)
    social_auth_state_from_response
  end

  def assert_oidc_authorize_redirect(location, host:, client_id: "base-rails-rp")
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal client_id, query["client_id"]
    assert_predicate query["state"], :present?
  end
end

# DAMP local helper copy on the test class.
class Auth::App::Sign::Up::Check::Email::OtpsControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )

  private

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    host_headers.merge("X-CSRF-Token" => csrf_token)
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(AUTH_APP AUTH_ORG ACME_APP ACME_ORG CORE_APP CORE_ORG BASE_APP BASE_ORG).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google_app] =
      OmniAuth::AuthHash.new(
        provider: "google_app", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end
