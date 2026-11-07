# frozen_string_literal: true

require "test_helper"

class EmailSignupHttpDeliveryCommitTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  include ActiveJob::TestHelper
  include SignInFlowCleanup
  include SignUpJourneyCleanup

  self.use_transactional_tests = false
  self.fixture_table_names = []

  setup do
    sign_up_journey_watermarks!
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  test "APP initial Email signup commits its Flow and OTP before enqueue" do
    previous_protection = ActionController::Base.allow_forgery_protection
    previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
    previous_challenge = [TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response]
    ActionController::Base.allow_forgery_protection = true
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    Client.maximum(:id) || 0
    ClientSignUpFlow.maximum(:id) || 0
    address = "signup-otp-#{SecureRandom.hex(12)}@example.test"

    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    browser = admitted_app_signup_browser(base_host:, auth_host:)
    browser.get("/sign/up/email/new", params: { ri: "jp" })

    assert_equal 200, browser.response.status
    clear_enqueued_jobs
    submit_initial_email(browser, address:, auth_host:)

    assert_equal 302, browser.response.status
    otp_uri = URI.parse(browser.response.location)
    signed_binding = Rack::Utils.parse_query(otp_uri.query).fetch("fb")
    decoded = SignFlowBindingCodec.decode(signed_binding)
    flow = ClientSignUpFlow.find_by!(public_id: decoded.flow_public_id)
    contact = ClientEmail.find(flow.pending_contact_id)
    transaction = ClientEmailCeremonyTransaction.find_by!(email_candidate_ref: contact.public_id)
    delivery =
      enqueued_jobs.find do |job|
        next false unless job.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
        notification.fetch(:params).fetch(:sign_up_email_transaction_ref) == transaction.transaction_id
      end
    notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
    delivery_params = notification.fetch(:params)
    code = OutboundSensitivePayload.decrypt_email_otp(delivery_params.fetch(:encrypted_hotp_token))

    assert_equal ClientSignUpFlowStatus::CONTACT_PENDING, flow.reload.status_id
    assert_equal "email", flow.pending_contact_type
    assert_equal contact.id, flow.pending_contact_id
    assert_predicate contact.reload.otp_last_sent_at, :present?
    assert_predicate transaction.reload.otp_verifier, :present?
    assert_equal flow.public_id, delivery_params.fetch(:sign_up_flow_ref)
    assert_equal transaction.otp_generation, delivery_params.fetch(:sign_up_email_otp_generation)
    assert_not JSON.generate(delivery.fetch(:args)).include?(code)

    generation_before_read = transaction.otp_generation
    browser.get(otp_uri.request_uri)

    assert_equal 200, browser.response.status
    assert_equal generation_before_read, transaction.reload.otp_generation

    csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    before_refusal = flow.reload.attributes
    browser.delete(
      otp_uri.path, params: { fb: "#{signed_binding}x", ri: "jp" }, headers: {
        "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf,
      },
    )

    assert_equal 409, browser.response.status
    assert_equal before_refusal, flow.reload.attributes
    browser.delete(
      otp_uri.request_uri, headers: {
        "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf,
      },
    )

    assert_equal 303, browser.response.status
    destination = URI.parse(jump_rt_url_from_location_for_test(browser.response.location))

    assert_equal "/oidc/cancellation", destination.path
    assert_equal Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host, destination.host
    assert_predicate flow.reload, :sign_up_cancelled?
    assert_signup_cancellation_interruption(browser, base_host:, auth_host:)
  ensure
    ActionController::Base.allow_forgery_protection = previous_protection
    TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = previous_turnstile
    TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = previous_challenge
    delete_sign_up_journey_rows!
  end

  test "APP signup after abandoning sign-in cannot use a registered email code or reach birthdate commit" do
    previous_protection = ActionController::Base.allow_forgery_protection
    previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
    previous_challenge = [TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response]
    ActionController::Base.allow_forgery_protection = true
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    Client.maximum(:id) || 0
    ClientSignUpFlow.maximum(:id) || 0
    base_host, auth_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL"), ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    address = "registered-signup-incident-#{SecureRandom.hex(10)}@example.test"
    owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::VERIFIED_WITH_SIGN_UP,
    )
    existing = owner.client_emails.create!(
      raw_address: address,
      confirm_policy: true,
      user_email_status_id: ClientEmailStatus::VERIFIED,
      binding_finalized_at: ClientEmail.database_now,
    )
    existing_facts = existing.reload.attributes
    owner_facts = owner.reload.attributes
    original_token_count = ClientToken.count
    clear_enqueued_jobs

    browser = admitted_app_signup_browser(base_host:, auth_host:)
    browser.get("/sign/up/email/new", params: { ri: "jp" })

    assert_equal 200, browser.response.status
    submit_initial_email(browser, address:, auth_host:)

    assert_equal 302, browser.response.status
    otp_uri = URI.parse(browser.response.location)
    flow_binding = Rack::Utils.parse_query(otp_uri.query).fetch("fb")
    flow = ClientSignUpFlow.find_by!(public_id: SignFlowBindingCodec.decode(flow_binding).flow_public_id)
    candidate = ClientEmail.find(flow.pending_contact_id)
    checkpoint_version = flow.checkpoint_version
    candidate_facts = candidate.reload.attributes
    candidate_owner_facts = Client.find(candidate.user_id).attributes
    flow_facts = flow.reload.attributes
    browser.get(otp_uri.request_uri)

    assert_equal 200, browser.response.status
    csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf }
    registered_page = JSON.parse(browser.response.parsed_body.at_css('script[data-page="app"]').text)
    registered_props = registered_page.fetch("props")
    resend = registered_props.fetch("otp_resend")

    assert_equal I18n.t("otp.resend.button"), resend.fetch("messages").fetch("button_label")
    delivery_count_before_resend =
      enqueued_jobs.count { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

    browser.post(
      resend.fetch("endpoint"), params: { state: resend.fetch("state") }, as: :json, headers:,
    )

    assert_equal 429, browser.response.status
    assert_not browser.response.parsed_body.fetch("resendable")
    assert_operator browser.response.parsed_body.fetch("retry_after"), :>, 0
    assert_equal delivery_count_before_resend,
                 enqueued_jobs.count { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

    resend_at = Time.current + EmailOtpPolicy::SEND_COOLDOWN + 1.second
    travel_to(resend_at) do
      browser.post(
        resend.fetch("endpoint"), params: { state: resend.fetch("state") }, as: :json, headers:,
      )
    end

    assert_equal 200, browser.response.status
    assert_equal({ "resendable" => true, "retry_after" => 0 }, browser.response.parsed_body)
    assert_equal delivery_count_before_resend,
                 enqueued_jobs.count { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

    browser.patch(
      otp_uri.request_uri,
      params: { :client_email => { pass_code: "123456" }, "cf-turnstile-response" => "test" },
      headers:,
    )

    assert_equal 422, browser.response.status
    registered_page = JSON.parse(browser.response.parsed_body.at_css('script[data-page="app"]').text)
    registered_props = registered_page.fetch("props")

    assert_includes registered_props.fetch("errors").join(" "),
                    I18n.t("sign.app.registration.email.update.invalid_code")
    assert_equal "auth/app/sign/up/emails/edit", registered_page.fetch("component")
    assert_equal "client_email", registered_props.fetch("scope")
    assert_empty enqueued_jobs.select { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }
    assert_equal candidate_facts, candidate.reload.attributes
    assert_equal candidate_owner_facts, Client.find(candidate.user_id).reload.attributes
    assert_equal flow_facts, flow.reload.attributes
    assert_equal existing_facts, existing.reload.attributes
    assert_equal owner_facts, owner.reload.attributes

    browser.patch(
      auth_app_sign_up_check_email_birthdate_path(ri: "jp", fb: flow_binding),
      params: { requirement: "birthdate", birthdate: "1990-01-15", checkpoint_version: checkpoint_version },
      headers:,
    )

    assert_equal 409, browser.response.status
    assert_equal existing_facts, existing.reload.attributes
    assert_equal owner_facts, owner.reload.attributes
    assert_equal original_token_count, ClientToken.count
    assert_equal 0, ClientToken.where(user_id: owner.id).count
    assert_equal 0, ClientToken.where(user_id: candidate.user_id).count
  ensure
    ActionController::Base.allow_forgery_protection = previous_protection
    TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = previous_turnstile
    TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = previous_challenge
    delete_sign_up_journey_rows!
  end

  test "APP initial Email signup remains reachable when notification enqueue is refused" do
    previous_protection = ActionController::Base.allow_forgery_protection
    previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
    previous_challenge = [TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response]
    ActionController::Base.allow_forgery_protection = true
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    Client.maximum(:id) || 0
    initial_flow_id = ClientSignUpFlow.maximum(:id) || 0
    address = "signup-otp-refused-#{SecureRandom.hex(12)}@example.test"
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    browser = admitted_app_signup_browser(base_host:, auth_host:)
    browser.get("/sign/up/email/new", params: { ri: "jp" })

    assert_equal 200, browser.response.status
    clear_enqueued_jobs
    Notify::App::OtpNotifier.stub(:issue, ->(**_arguments) { raise ActiveJob::EnqueueError, "test refusal" }) do
      submit_initial_email(browser, address:, auth_host:)
    end

    assert_equal 503, browser.response.status
    flow = ClientSignUpFlow.where("id > ?", initial_flow_id).sole
    contact = ClientEmail.find_by!(address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :app))
    transaction = ClientEmailCeremonyTransaction.find_by!(email_candidate_ref: contact.public_id)

    assert_equal ClientSignUpFlowStatus::CONTACT_PENDING, flow.reload.status_id
    assert_equal contact.id, flow.pending_contact_id
    assert_predicate contact.reload.otp_last_sent_at, :present?
    assert_predicate transaction.reload.otp_verifier, :present?

    binding = SignFlowBindingCodec.encode(flow:, surface: :app)
    browser.get(auth_app_sign_up_check_email_otp_path(ri: "jp", fb: binding))

    assert_equal 200, browser.response.status
  ensure
    ActionController::Base.allow_forgery_protection = previous_protection
    TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = previous_turnstile
    TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = previous_challenge
    delete_sign_up_journey_rows!
  end

  test "APP telephone OTP cancellation reaches the shared interruption page" do
    previous_protection = ActionController::Base.allow_forgery_protection
    previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
    ActionController::Base.allow_forgery_protection = true
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    initial_client_id = Client.maximum(:id) || 0
    initial_flow_id = ClientSignUpFlow.maximum(:id) || 0
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    browser = admitted_app_signup_browser(base_host:, auth_host:)
    browser.get("/sign/up/telephone/new", params: { ri: "jp" })
    csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    browser.post(
      "/sign/up/telephone", params: {
        :client_telephone => { raw_number: "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}",
                               confirm_policy: "1",
                               confirm_using_mfa: "1", },
        "cf-turnstile-response" => "test",
        :ri => "jp",
      }, headers: { "Origin" => "https://#{auth_host}", "X-CSRF-Token" => csrf, "Sec-Fetch-Site" => "same-origin" },
    )

    assert_equal 302, browser.response.status
    target = URI.parse(browser.response.location)
    binding = SignFlowBindingCodec.decode(Rack::Utils.parse_query(target.query).fetch("fb"))
    flow = ClientSignUpFlow.find_by!(public_id: binding.flow_public_id)
    browser.get(target.request_uri)

    assert_equal 200, browser.response.status
    csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    browser.delete(
      target.request_uri, headers: {
        "Origin" => "https://#{auth_host}", "X-CSRF-Token" => csrf, "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_equal 303, browser.response.status
    assert_predicate flow.reload, :sign_up_cancelled?
    assert_signup_cancellation_interruption(browser, base_host:, auth_host:)
  ensure
    ActionController::Base.allow_forgery_protection = previous_protection
    TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = previous_turnstile
    if initial_flow_id
      telephone_refs = ClientTelephone.where("user_id > ?", initial_client_id).pluck(:public_id)
      ClientTelephoneCeremonyTransaction.where(telephone_candidate_ref: telephone_refs).delete_all
    end
    delete_sign_up_journey_rows!
  end

  [
    ["Sign In method selection", "/sign/in", false, "cancel_form"],
    ["Sign In Email address", "/sign/in/email/new", false, "cancel"],
    ["Sign In Passkey", "/sign/in/passkey/new", false, "cancel"],
    ["Sign In Secret", "/sign/in/secret/new", false, "parent_cancel"],
    ["Sign Up method selection", "/sign/up", true, "cancel_form"],
    ["Sign Up Email address", "/sign/up/email/new", true, "cancel"],
    ["Sign Up Telephone number", "/sign/up/telephone/new", true, "cancel"],
  ].each do |label, path, signup, cancel_key|
    test "APP #{label} Cancel ends the parent through Visa and renders Base interruption" do
      previous_protection = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      browser = open_session
      browser.host!(base_host)
      browser.https!
      begin_app_signup_admission!(browser, base_host)
      follow_app_signup_handoff!(browser, base_host:, auth_host:)
      switch_browser_to_sign_up!(browser, surface: "app") if signup
      browser.get(path, params: { ri: "jp" })

      assert_equal 200, browser.response.status
      page = JSON.parse(browser.response.parsed_body.at_css('script[data-page="app"]').text)
      props = page.fetch("props")
      cancel = props.fetch(cancel_key)
      unless cancel_key == "cancel_form"
        up = signup ? props.fetch("links").find { |link| link.fetch("key") == "back" } : props.fetch("back_link")

        assert_equal I18n.t("actions.back"), up.fetch("label")
        assert_equal signup ? "/sign/up" : "/sign/in", URI.parse(up.fetch("href")).path
      end

      assert_predicate cancel, :present?
      assert_equal "/sign/cancellation", URI.parse(cancel.fetch("action")).path
      csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(browser.cookies[cookie_name])

      assert_predicate ceremony, :present?
      parent = ClientOidcAuthorizationTransaction.find_by!(transaction_id: ceremony.authorization_transaction_ref)
      csrf_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
      browser.post(cancel.fetch("action"), params: { authenticity_token: csrf }, headers: csrf_headers)

      assert_equal 303, browser.response.status
      assert_predicate ceremony.reload, :cancelled?
      assert_predicate parent.reload, :canceled?
      assert_signup_cancellation_interruption(browser, base_host:, auth_host:)
    ensure
      ActionController::Base.allow_forgery_protection = previous_protection
    end
  end

  test "APP Email receipt preserves a committed registration after the OP completion update fails" do
    previous_protection = ActionController::Base.allow_forgery_protection
    previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
    previous_challenge = [TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response]
    ActionController::Base.allow_forgery_protection = true
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    Client.maximum(:id) || 0
    ClientSignUpFlow.maximum(:id) || 0
    base_host, auth_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL"), ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    browser = admitted_app_signup_browser(base_host:, auth_host:)
    browser.get("/sign/up/email/new", params: { ri: "jp" })
    clear_enqueued_jobs
    submit_initial_email(browser, address: "receipt-#{SecureRandom.hex(12)}@example.test", auth_host:)

    assert_equal 302, browser.response.status
    otp_uri = URI.parse(browser.response.location)
    flow_ref = SignFlowBindingCodec.decode(Rack::Utils.parse_query(otp_uri.query).fetch("fb")).flow_public_id
    flow = ClientSignUpFlow.find_by!(public_id: flow_ref)
    delivery = enqueued_jobs.find { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }
    params = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last.fetch(:params)
    code = OutboundSensitivePayload.decrypt_email_otp(params.fetch(:encrypted_hotp_token))
    browser.get(otp_uri.request_uri)
    csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf }
    browser.patch(
      otp_uri.request_uri, params: {
        :client_email => { pass_code: code }, "cf-turnstile-response" => "test",
      }, headers:,
    )

    assert_includes [302, 303], browser.response.status
    checkpoint = URI.parse(browser.response.location)
    browser.get(checkpoint.request_uri)

    assert_equal 200, browser.response.status
    injected = false
    failure =
      lambda do |event|
        payload = event.payload
        if payload[:name] == "ClientSignUpFlow Update" && payload[:sql].include?('"status_id"') &&
            ClientRegistrationCompletion.exists?(sign_up_flow_ref: flow.public_id)
          injected = true
          raise ActiveRecord::StatementInvalid, "OP completion unavailable after source commit"
        end
      end

    error =
      ActiveSupport::Notifications.subscribed(failure, "sql.active_record") do
        assert_raises(ActiveRecord::StatementInvalid) do
          browser.patch(
            checkpoint.request_uri, params: {
              requirement: "birthdate", checkpoint_version: flow.reload.checkpoint_version, birthdate: "1990-01-15",
            }, headers:,
          )
        end
      end

    assert injected, "the injected failure must occur after the Source receipt commits"
    assert_equal "OP completion unavailable after source commit", error.message
    actor = Client.find(flow.principal_id)
    contact = ClientEmail.find(flow.pending_contact_id)
    receipt = ClientRegistrationCompletion.find_by!(client_id: actor.id)

    assert_equal [flow.public_id, 1, ClientStatus::VERIFIED_WITH_SIGN_UP, ClientSignUpFlowStatus::FINALIZING],
                 [receipt.sign_up_flow_ref, receipt.method_id, actor.status_id, flow.reload.status_id]
    binding = flow.association(:auth_admission_binding).scope.take!
    parent = binding.association(:authorization_transaction).scope.take!
    parent.prepare_cancellation_handoff!(reference: SecureRandom.uuid, ciphertext: "receipt-test-cancellation")
    parent.cancel!(cancellation_handoff_digest: Digest::SHA256.hexdigest("receipt-test-parent"))
    before = [actor.attributes, contact.attributes, receipt.attributes,
              ClientContactAuditOutbox.where(operation_ref: flow.public_id).pluck(:id),]
    ClientSignUpFlow.stub(:database_now, flow.expires_at + 1.second) do
      SignUpTermination.call(cycle: flow, event: :expire)
      SignUpArtifactCleanup.call(cycle: flow)
    end

    assert_predicate flow.reload, :sign_up_completed?
    assert_equal before, [actor.reload.attributes, contact.reload.attributes, receipt.reload.attributes,
                          ClientContactAuditOutbox.where(operation_ref: flow.public_id).pluck(:id),]
    assert_equal 0, ClientToken.where(user_id: actor.id).count
  ensure
    ActionController::Base.allow_forgery_protection = previous_protection
    TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = previous_turnstile
    TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = previous_challenge
    delete_sign_up_journey_rows!
  end

  private

  def assert_signup_cancellation_interruption(browser, base_host:, auth_host:)
    visa_host = Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host
    target = URI.parse(jump_rt_url_from_location_for_test(browser.response.location))

    assert_equal visa_host, target.host
    assert_equal "/oidc/cancellation", target.path
    browser.host!(visa_host)
    browser.get(
      target.request_uri, headers: {
        "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
      },
    )

    assert_equal 200, browser.response.status
    form = browser.response.parsed_body.at_css("form#visa-authorization-continuation-form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    browser.post(
      form["action"], params: fields, headers: {
        "Origin" => "https://#{visa_host}",
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      },
    )

    assert_cancellation_callback(browser, base_host:)
    follow_app_signup_handoff!(browser, base_host:, auth_host:)

    assert_equal base_host, browser.host
    assert_equal "/sign/interruption", browser.request.path
    assert_equal 200, browser.response.status
  end

  def assert_cancellation_callback(browser, base_host:)
    assert_equal 303, browser.response.status
    callback = URI.parse(jump_rt_url_from_location_for_test(browser.response.location))
    callback_query = Rack::Utils.parse_query(callback.query)

    assert_equal base_host, callback.host
    assert_equal "/oidc/callback", callback.path
    assert_equal "access_denied", callback_query.fetch("error")
    assert_not callback_query.key?("code")
  end

  def admitted_app_signup_browser(base_host:, auth_host:)
    browser = open_session
    browser.host!(base_host)
    browser.https!
    begin_app_signup_admission!(browser, base_host)
    follow_app_signup_handoff!(browser, base_host:, auth_host:)

    assert_equal 200, browser.response.status
    assert_equal auth_host, browser.host
    switch_browser_to_sign_up!(browser, surface: "app")
    browser
  end

  def begin_app_signup_admission!(browser, base_host)
    browser.get("/sign", params: { ri: "jp" })

    assert_equal 200, browser.response.status
    csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    browser.post(
      "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: {
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_equal 303, browser.response.status
  end

  def follow_app_signup_handoff!(browser, base_host:, auth_host:)
    boot = Rails.configuration.x.boot_config
    jump_host = URI.parse(boot.fetch(:jump).origin.to_s).host
    visa_host = boot.fetch(:hosts).visa_service.host
    12.times do
      break unless browser.response.redirect?

      target = resolve_app_signup_redirect(
        browser, base_host:, auth_host:, jump_host:, visa_host:, audience: boot.fetch(:jump).audience,
      )

      browser.host!(target.host)
      browser.https!
      browser.get(
        target.request_uri, headers: {
          "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
        },
      )
    end
  end

  def resolve_app_signup_redirect(browser, base_host:, auth_host:, jump_host:, visa_host:, audience:)
    target = URI.parse(browser.response.location)
    target = URI.parse("https://#{browser.host}#{target}") if target.host.blank?
    return target unless target.host == jump_host

    token = Rack::Utils.parse_nested_query(target.query.to_s).fetch("rt")
    source =
      case browser.host
      when base_host then "BASE_APP"
      when visa_host then "VISA_APP"
      when auth_host then "AUTH_APP"
      else raise ArgumentError, "unexpected APP signup handoff source"
      end
    issuer = JitSecurityJwtRegistry.surface(source)
    payload, = JWT.decode(
      token, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
      algorithms: ["ES384"], verify_iss: true, iss: "https://#{browser.host}",
      verify_aud: true, aud: audience,
    )
    resolved = URI.parse(payload.fetch("url"))

    assert_includes [base_host, visa_host, auth_host], resolved.host
    resolved
  end

  def submit_initial_email(browser, address:, auth_host:)
    csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    browser.post(
      "/sign/up/email", params: {
        "client_email" => { "raw_address" => address, "confirm_policy" => "1" },
        "cf-turnstile-response" => "test",
        "ri" => "jp",
      }, headers: {
        "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf,
      },
    )
  end
end
