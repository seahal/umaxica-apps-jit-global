# typed: false
# frozen_string_literal: true

# Snapshot diffs would expose OTP material and browser-bound token state on failure.

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::Sign::Up::EmailsControllerTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  include ActiveSupport::Testing::TimeHelpers

  setup do
    ClientSignInFlowState::DEFAULTS.each { |id| ClientSignInFlowState.find_or_create_by!(id: id) }
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    reset_cookie_jar!
    cookies["csrf_token"] = csrf_token_value
    Rails.configuration.x.rate_limit.fetch(:store).clear
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    https!
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_up", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    get(auth_app_sign_up_path(ri: "jp"), params: { entry_ref: issuance.reference })

    assert_response :success
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    admission_headers = { "Origin" => "https://#{request.host}", "Sec-Fetch-Site" => "same-origin" }
    post(
      "/ceremony_bindings", params: { entry_ref: issuance.reference, ri: "jp", authenticity_token: csrf },
                            headers: admission_headers,
    )

    assert_response :see_other
    # Public confirmation isolates this leaf's setup; separate HTTP tests exercise the Base receiver.
    binding.reload.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get(auth_app_sign_up_path(ri: "jp"), params: { entry_ref: issuance.reference })

    assert_response :success
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      auth_app_sign_up_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf },
                                       headers: admission_headers,
    )

    assert_response :see_other
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    Rails.configuration.x.rate_limit.fetch(:store).clear
    reset_cookie_jar!
  end

  test "should get new" do
    get new_auth_app_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success
    # The widget and its hidden response field are the React component's
    # (gait/features/auth/signup/contact_sign_up_form.test.tsx); what the server owns is the
    # visible-mode configuration it hands over.
    turnstile = inertia_props.fetch("turnstile")

    assert_equal "render", turnstile.fetch("mode")
    assert_predicate turnstile.fetch("site_key"), :present?
    assert_select "script[type='module'][src*='vite']", minimum: 1
    assert_nil response.headers["Content-Security-Policy-Report-Only"]
    assert_includes response.headers["Content-Security-Policy"], "default-src 'self'"
    assert_not_includes response.headers["Content-Security-Policy"], "'unsafe-inline'"
  end

  test "direct email entry route no longer exists" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}/sign/up/email",
        method: :get,
      )
    end
  end

  test "create executes server-side visible Turnstile verification" do
    calls = []
    verifier =
      lambda do |token:, remote_ip:, mode:, **|
        calls << { token: token, remote_ip: remote_ip, mode: mode }
        { "success" => false }
      end

    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.stub(:verify, verifier) do
      post(
        auth_app_sign_up_email_url(ri: "jp"),
        params: {
          user_email: {
            raw_address: "turnstile-signup-#{SecureRandom.hex(4)}@example.com",
            confirm_policy: "1",
          },
          "cf-turnstile-response": "signup-token",
        },
        headers: default_headers,
      )
    end

    assert_response :unprocessable_content
    assert_equal [{ token: "signup-token", remote_ip: "127.0.0.1", mode: :visible }], calls
  ensure
    TurnstileVerifierStub.challenge_enabled = true
  end

  test "collection get redirects to add ri" do
    get new_auth_app_sign_up_email_url(ri: nil, hotwire_spark: true, reload: "123"), headers: default_headers

    assert_response :redirect
  end

  test "renders email registration form structure" do
    get new_auth_app_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success

    assert_equal "auth/app/sign/up/emails/new", inertia_component
    assert_equal I18n.t("sign.app.registration.email.new.page_title"), inertia_props.fetch("title")
    assert_equal "client_email", inertia_props.fetch("scope")
    assert_equal "", inertia_props.fetch("field").fetch("value")
    checkbox_names = inertia_props.fetch("checkboxes").map { |checkbox| checkbox.fetch("name") }

    assert_equal 1, checkbox_names.count("promotional")
    assert_equal 1, checkbox_names.count("notifiable")
    assert_no_match(/UMAXICA \(sign, app\)/, response.body)
  end

  test "includes navigation links to other registration flows" do
    get new_auth_app_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success

    # The links a specific ceremony needs live in the page body; the shared auth header carries no
    # sign-in/sign-up navigation of its own.
    page_links = inertia_props.fetch("links").map { |link| link.fetch("href") }

    assert_equal 1, page_links.count(auth_app_sign_up_path(ri: "jp"))
    assert_equal 1, page_links.count(new_auth_app_sign_in_email_path(ri: "jp"))
    assert_not inertia_props.fetch("chrome").key?("primary_navigation")
  end

  test "edit requires a signed flow binding even when the browser has its current sequence" do
    # Establish flow state by starting a registration
    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "flow_setup@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    target = response.location
    cycle = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
    candidate = ClientEmail.find(cycle.pending_contact_id)
    cycle_facts = cycle.reload.attributes
    candidate_facts = candidate.reload.attributes
    get target, headers: default_headers

    assert_response :success
    assert_equal "auth/app/sign/up/emails/edit", inertia_component
    assert_equal I18n.t("sign.app.authentication.email.edit.page_title"), inertia_props.fetch("title")
    assert_equal I18n.t("sign.app.authentication.email.edit.code_label"), inertia_props.fetch("code_label")
    assert_equal(
      I18n.t("sign.app.authentication.email.edit.code_placeholder"),
      inertia_props.fetch("code_placeholder"),
    )
    assert_equal "client_email", inertia_props.fetch("scope")
    assert_equal I18n.t("sign.app.authentication.email.edit.submit"), inertia_props.fetch("submit_label")
    assert_includes response.body, "メールアドレス"
    assert_equal(
      I18n.t("sign.app.authentication.email.edit.delivery_help"),
      inertia_props.fetch("delivery_help"),
    )

    get auth_app_sign_up_check_email_otp_url(ri: "jp"), headers: default_headers

    assert_response :conflict
    assert_withheld("a sequence id cannot replace browser authority") { cycle_facts == cycle.reload.attributes }
    assert_withheld("missing browser authority preserves candidate evidence") {
      candidate_facts == candidate.reload.attributes
    }
  end

  test "update accepts a valid otp submitted through client_email" do
    user_email = start_sign_up_flow!("client@example.com")
    otp_query = Rack::Utils.parse_query(URI.parse(response.location).query)
    bound_flow = SignFlowBindingCodec.decode(otp_query.fetch("fb"))

    assert_equal "app", bound_flow.surface
    assert_equal "sign_up", bound_flow.kind
    assert_equal current_sign_up_flow(user_email).public_id, bound_flow.flow_public_id
    # Follow the OTP redirect produced by the create action.
    follow_redirect!
    pass_code = otp_code_for(user_email)

    patch auth_app_sign_up_check_email_otp_url(ri: "jp"),
          params: otp_query.merge("client_email" => { pass_code: pass_code }, "cf-turnstile-response" => "test"),
          headers: default_headers

    assert_response :redirect
    checkpoint = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), checkpoint.host
    assert_equal "https", checkpoint.scheme
    assert_equal URI.parse(auth_app_sign_up_check_email_birthdate_path(ri: "jp")).path, checkpoint.path
    checkpoint_query = Rack::Utils.parse_query(checkpoint.query)

    assert_equal "jp", checkpoint_query.fetch("ri")
    assert_equal bound_flow, SignFlowBindingCodec.decode(checkpoint_query.fetch("fb"))
    assert_nil flash[:notice]
  end

  test "i18n messages for email registration flow exist" do
    # Check that all required i18n keys for email registration exist
    session_expired_key = "sign.app.registration.email.edit.session_expired"
    create_key = "sign.app.registration.email.create.verification_code_sent"
    update_key = "sign.app.registration.email.update.success"

    assert_not_nil I18n.t(session_expired_key, default: nil)
    assert_not_nil I18n.t(create_key, default: nil)
    assert_not_nil I18n.t(update_key, default: nil)
  end

  test "can re-register same email if previous registration was unverified" do
    email = "test_re_reg@example.com"

    # First registration attempt
    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    # Verify first record created - extract ID from redirect location
    first_email_id = ClientEmail.order(:created_at).last.public_id
    first_email = ClientEmail.find_by(public_id: first_email_id)

    assert_not_nil first_email
    assert_equal ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, first_email.user_email_status_id

    assert_not_nil first_email.address_digest

    # Second registration attempt after the independent overwrite window expires (case-variant)
    # This should delete the previous unverified record and create a new one
    travel EmailOtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "TEST_RE_REG@EXAMPLE.COM",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers

      # Should succeed because old unverified record is deleted
      assert_response :redirect

      # Verify old record was deleted and new record was created
      new_email_id = ClientEmail.order(:created_at).last.public_id

      assert_not_equal first_email.id, new_email_id # Check IDs from URL differ
    end
  end

  test "create redirects to edit and allows edit page" do
    email = "flow_step_test@example.com"

    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    follow_redirect!

    assert_response :success
    assert_equal "/sign/up/check/email/otp", path
  end

  test "create renders unprocessable when user_email param missing" do
    assert_no_difference("ClientEmail.count") do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: { "cf-turnstile-response": "test" },
           headers: default_headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.create.address_required")
  end

  test "create renders unprocessable when turnstile fails" do
    TurnstileVerifierStub.challenge_response = { "success" => false }

    assert_no_difference("ClientEmail.count") do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "turnstile-failure@example.com",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.create.turnstile_validation_failed")
  end

  test "create beside an effective email owns a new candidate without changing the original binding" do
    user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
    existing_email = ClientEmail.create!(
      user: user,
      address: "existing_signup@example.com",
      confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      binding_finalized_at: ClientEmail.database_now,
    )
    original_contact_facts = existing_email.reload.attributes
    original_owner_facts = user.reload.attributes
    original_root_count = ClientToken.count

    assert_difference("Client.count", 1) do
      assert_difference("ClientEmail.count", 1) do
        assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
          post auth_app_sign_up_email_url(ri: "jp"),
               params: {
                 user_email: {
                   raw_address: existing_email.address,
                   confirm_policy: "1",
                 },
                 "cf-turnstile-response": "test",
               },
               headers: default_headers
        end
      end
    end

    assert_response :redirect
    target = URI.parse(response.location)
    flow_binding = Rack::Utils.parse_query(target.query).fetch("fb")
    flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
    candidate = ClientEmail.find(flow.pending_contact_id)

    assert_redirected_to auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding)
    assert_equal flow.public_id, SignFlowBindingCodec.decode(flow_binding).flow_public_id
    assert_not_equal user.id, candidate.user_id
    assert_nil candidate.binding_finalized_at
    assert_withheld("original binding and OTP facts remain unchanged") {
      original_contact_facts == existing_email.reload.attributes
    }
    assert_withheld("original owner facts remain unchanged") { original_owner_facts == user.reload.attributes }
    assert_equal original_root_count, ClientToken.count

    follow_redirect!

    assert_response :success
    assert_includes response.body, I18n.t("sign.app.registration.email.create.verification_code_sent")
    assert_not_includes response.body, I18n.t("sign.app.registration.email.new.error_summary")
    assert_not_includes response.body, I18n.t("errors.messages.taken")
  end

  test "create beside a non-finalized verified signup candidate owns independent evidence" do
    existing_user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
    existing_email = ClientEmail.create!(
      user: existing_user,
      address: "completed-signup@example.com",
      confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED_WITH_SIGN_UP,
    )
    original_contact_facts = existing_email.reload.attributes
    original_owner_facts = existing_user.reload.attributes
    original_root_count = ClientToken.count

    assert_difference("Client.count", 1) do
      assert_difference("ClientEmail.count", 1) do
        assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
          post auth_app_sign_up_email_url(ri: "jp"),
               params: {
                 user_email: {
                   raw_address: "completed-signup@example.com",
                   confirm_policy: "1",
                 },
                 "cf-turnstile-response": "test",
               },
               headers: default_headers
        end
      end
    end

    assert_response :redirect
    flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
    candidate = ClientEmail.find(flow.pending_contact_id)

    assert_redirected_to auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding)
    assert_equal flow.public_id, SignFlowBindingCodec.decode(flow_binding).flow_public_id
    assert_not_equal existing_email.id, candidate.id
    assert_not_equal existing_user.id, candidate.user_id
    assert_nil candidate.binding_finalized_at
    assert_withheld("other candidate facts remain unchanged") {
      original_contact_facts == existing_email.reload.attributes
    }
    assert_withheld("other candidate owner facts remain unchanged") {
      original_owner_facts == existing_user.reload.attributes
    }
    assert_equal original_root_count, ClientToken.count
  end

  test "create enqueues exactly one email" do
    email = "enqueue_test@example.com"

    assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :redirect
  end

  test "create stores requested email preference flags" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "signup-preferences@example.com",
             confirm_policy: "1",
             promotional: "0",
             notifiable: "0",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by!(public_id: email_id)

    assert_not user_email.promotional
    assert_not user_email.notifiable
  end

  test "create delivers only the independent candidate OTP and preserves an effective contact OTP" do
    user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
    existing_email = ClientEmail.create!(
      user: user,
      address: "no_otp_send@example.com",
      confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      binding_finalized_at: ClientEmail.database_now,
    )
    before_otp_last_sent_at = existing_email.otp_last_sent_at
    before_otp_attempts_count = existing_email.otp_attempts_count

    assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "no_otp_send@example.com",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :redirect
    assert_equal before_otp_last_sent_at, existing_email.reload.otp_last_sent_at
    assert_not existing_email.attributes.key?("otp_counter")
    assert_equal before_otp_attempts_count, existing_email.otp_attempts_count
  end

  test "fresh sessions cannot distinguish pending and registered email sign-up" do
    user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
    existing = ClientEmail.create!(
      user: user, raw_address: "app-fresh-session-registered-signup@example.com", confirm_policy: true,
      user_email_status_id: ClientEmailStatus::VERIFIED,
      binding_finalized_at: ClientEmail.database_now,
    )
    existing_facts = existing.reload.attributes
    existing_owner_facts = user.reload.attributes
    responses = []
    candidates = []
    browsers = []
    targets = []

    [existing.address, "app-fresh-session-pending-signup@example.com"].each do |destination|
      2.times do
        browser = open_session
        browser.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
        browser.https!
        issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "app", intent: "sign_up", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
        )
        binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
        browser.get(auth_app_sign_up_path(ri: "jp"), params: { entry_ref: issuance.reference })

        assert_equal 200, browser.response.status
        csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        headers = { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin" }
        browser.post(
          "/ceremony_bindings",
          params: { entry_ref: issuance.reference, ri: "jp", authenticity_token: csrf }, headers: headers,
        )

        assert_equal 303, browser.response.status
        binding.reload.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        browser.get(auth_app_sign_up_path(ri: "jp"), params: { entry_ref: issuance.reference })
        csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        browser.post(
          auth_app_sign_up_path(ri: "jp"),
          params: { entry_ref: issuance.reference, authenticity_token: csrf }, headers: headers,
        )

        assert_equal 303, browser.response.status
        assert_difference("ClientEmail.count", 1) do
          browser.post(
            auth_app_sign_up_email_url(ri: "jp"),
            params: { user_email: { raw_address: destination, confirm_policy: "1" },
                      "cf-turnstile-response": "test", }, headers: headers,
          )
        end

        assert_equal 302, browser.response.status
        target = URI.parse(browser.response.location)
        query = Rack::Utils.parse_query(target.query)

        assert_equal %w(fb ri), query.keys.sort
        assert_equal "jp", query.fetch("ri")
        responses << [browser.response.status, target.scheme, target.host, target.path, query.keys.sort]
        candidate = ClientEmail.order(:created_at, :id).last
        candidates << candidate
        browsers << browser
        targets << target

        assert_equal destination, candidate.address
        assert_nil candidate.binding_finalized_at
      end
    end

    assert_equal 1, responses.uniq.length
    assert_equal 4, candidates.map(&:id).uniq.length
    assert_equal 4, candidates.map(&:user_id).uniq.length
    assert_withheld("protected record facts remain unchanged") { existing_facts == existing.reload.attributes }
    assert_withheld("protected record facts remain unchanged") { existing_owner_facts == user.reload.attributes }
    own_candidate_facts = candidates.last.attributes
    foreign_candidate_facts = candidates.first.attributes
    browsers.last.get(targets.first.request_uri)

    assert_equal 409, browsers.last.response.status
    assert_withheld("protected record facts remain unchanged") {
      own_candidate_facts == candidates.last.reload.attributes
    }
    assert_withheld("protected record facts remain unchanged") {
      foreign_candidate_facts == candidates.first.reload.attributes
    }
    foreign_delivery =
      (enqueued_jobs + performed_jobs).find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
        notification.fetch(:params).fetch(:public_id) == candidates.first.public_id
      end
    foreign_notification = ActiveJob::Arguments.deserialize(foreign_delivery.fetch(:args)).last
    foreign_code = OutboundSensitivePayload.decrypt_email_otp(
      foreign_notification.fetch(:params).fetch(:encrypted_hotp_token),
    )
    assert_no_difference("ClientToken.count") do
      browsers.last.patch(
        targets.first.request_uri,
        params: { user_email: { pass_code: foreign_code }, "cf-turnstile-response": "test" },
        headers: { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin" },
      )
    end

    assert_equal 409, browsers.last.response.status
    assert_withheld("foreign proof cannot affect this candidate") {
      own_candidate_facts == candidates.last.reload.attributes
    }
    assert_withheld("foreign proof cannot consume its candidate") {
      foreign_candidate_facts == candidates.first.reload.attributes
    }
    browsers.last.get(targets.last.request_uri)

    assert_equal 200, browsers.last.response.status
  end

  test "create with validation failure enqueues no emails and returns 422" do
    email = "invalid_email"

    assert_enqueued_jobs 0, only: OtpNotifierEmailDeliveryJob do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :unprocessable_content
    assert_equal email, inertia_props.fetch("field").fetch("value")
    assert_includes @response.body, I18n.t("sign.app.registration.email.new.error_summary")
    assert_not_includes @response.body, "prohibited this sample from being saved"
  end

  test "create without policy confirmation shows localized validation summary" do
    logs = []

    assert_enqueued_jobs 0, only: OtpNotifierEmailDeliveryJob do
      Rails.logger.stub(:info, ->(*args, &block) { logs << (args.first || block&.call).to_s }) do
        post auth_app_sign_up_email_url(ri: "jp"),
             params: {
               user_email: {
                 raw_address: "policy_missing@example.com",
                 confirm_policy: "0",
               },
               "cf-turnstile-response": "test",
             },
             headers: default_headers
      end
    end

    assert_response :unprocessable_content
    assert_equal "policy_missing@example.com", inertia_props.fetch("field").fetch("value")
    assert_includes @response.body, I18n.t("sign.app.registration.email.new.error_summary")
    assert_includes @response.body, ClientEmail.human_attribute_name(:confirm_policy)
    assert_not_includes @response.body, "prohibited this sample from being saved"
    assert_no_match(/policy_missing@example\.com/, logs.join("\n"))
  end

  test "create with turnstile failure enqueues no emails and returns 422" do
    TurnstileVerifierStub.challenge_response = { "success" => false }

    email = "turnstile_fail@example.com"

    assert_enqueued_jobs 0, only: OtpNotifierEmailDeliveryJob do
      post(
        auth_app_sign_up_email_url(ri: "jp"),
        params: {
          user_email: {
            raw_address: email,
            confirm_policy: "1",
          },
          "cf-turnstile-response": "test",
        },
        headers: default_headers,
      )
    end

    assert_response :unprocessable_content
    assert_equal email, inertia_props.fetch("field").fetch("value")
    assert_includes @response.body, I18n.t("sign.app.registration.email.create.turnstile_validation_failed")
  ensure
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  test "rejects wrong OTP codes with error message" do
    flow_binding = nil
    email = "test_wrong_otp@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
      flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    end

    # Extract email ID from redirect location
    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)

    # Attempt wrong code
    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
          params: {
            "cf-turnstile-response" => "test",
            :id => user_email.id,
            :user_email => {
              pass_code: "000000",
            },
          },
          headers: default_headers

    assert_response :unprocessable_content
    assert_includes @response.body, "正しくありません"
  end

  test "update with blank code returns 422 and renders edit" do
    flow_binding = nil
    email = "blank_code_test@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
      flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    end

    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)

    # Attempt with blank code
    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
          params: {
            "cf-turnstile-response" => "test",
            :id => user_email.id,
            :user_email => {
              pass_code: "",
            },
          },
          headers: default_headers

    assert_response :unprocessable_content
    assert_includes @response.body, I18n.t("sign.app.registration.email.update.code_required")
  end

  test "update at the candidate OTP deadline refuses without clearing flow requirements" do
    flow_binding = nil
    email = "expired_test@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
      flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    end

    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)

    cycle = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
    cycle_facts = cycle.reload.attributes
    contact_facts = user_email.reload.attributes
    transaction = ClientEmailCeremonyTransaction.where(
      operation: "sign_up",
      email_candidate_ref: user_email.public_id,
    ).sole
    ClientEmailCeremonyTransaction.stub(:database_now, transaction.otp_expires_at) do
      patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
            params: {
              "cf-turnstile-response" => "test",
              :id => user_email.id,
              :user_email => {
                pass_code: "123456",
              },
            },
            headers: default_headers

      assert_response :found
      assert_redirected_to new_auth_app_sign_up_email_url(ri: "jp")
      assert_withheld("OTP expiry does not manufacture checkpoint progress") { cycle_facts == cycle.reload.attributes }
      assert_withheld("expired OTP evidence is not consumed or replaced") {
        contact_facts == user_email.reload.attributes
      }
    end
  end

  test "max OTP attempts renders lockout error without clearing otp" do
    flow_binding = nil
    email = "test_max_attempts@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
      flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    end

    # Extract email ID from redirect location
    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)
    cycle = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
    completed_requirements = cycle.completed_requirements.deep_dup

    Email::MAX_OTP_ATTEMPTS.times do
      patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
            params: {
              "cf-turnstile-response" => "test",
              :id => user_email.id,
              :user_email => {
                pass_code: "000000",
              },
            },
            headers: default_headers
    end

    assert_response :too_many_requests
    assert_includes response.body, I18n.t("sign.app.registration.email.update.attempts_exceeded")
    assert_empty flash.to_hash
    assert ClientEmail.exists?(public_id: user_email.public_id)
    assert_predicate user_email.reload, :locked?
    assert_equal completed_requirements, cycle.reload.completed_requirements
    assert_nil cycle.completed_requirements["otp"]
  end

  test "telephone i18n messages exist" do
    # Check that all required i18n keys for telephone registration exist
    session_expired_key = "sign.app.registration.telephone.edit.session_expired"
    create_key = "sign.app.registration.telephone.create.verification_code_sent"
    update_key = "sign.app.registration.telephone.update.success"

    assert_not_nil I18n.t(session_expired_key, default: nil)
    assert_not_nil I18n.t(create_key, default: nil)
    assert_not_nil I18n.t(update_key, default: nil)
  end

  # Turnstile Widget Verification Tests
  test "new registration email page renders Turnstile widget" do
    get new_auth_app_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_equal "render", inertia_props.fetch("turnstile").fetch("mode")
  end

  test "turnstile validation error message i18n key exists" do
    # Verify the turnstile error message key exists in all locales
    assert_not_nil I18n.t(
      "sign.app.registration.email.create.turnstile_validation_failed", locale: :ja,
                                                                        default: nil,
    )
    assert_not_nil I18n.t(
      "sign.app.registration.email.create.turnstile_validation_failed", locale: :en,
                                                                        default: nil,
    )
  end

  test "new rejects when user is already logged in" do
    # Create a user and log them in
    user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)

    # Try to access registration page while logged in (using test header to inject current user)
    get new_auth_app_sign_up_email_url(ri: "jp"),
        headers: as_user_headers(user, host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))

    assert_response :unauthorized
    assert_equal I18n.t("errors.messages.already_authenticated"), response.body
  end

  test "create rejects when user is already logged in" do
    user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)

    assert_no_difference("ClientEmail.count") do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "logged-in@example.com",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: as_user_headers(
             user,
             host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
             headers: default_headers,
           )
    end

    assert_response :unauthorized
    assert_equal I18n.t("errors.messages.already_authenticated"), response.body
  end

  test "redirects to encoded URL after successful registration when pt parameter is provided" do
    email = "redirect_test_#{SecureRandom.hex(4)}@example.com"
    redirect_url = "/dashboard"

    # Create registration record with pt parameter
    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
           pt: redirect_url,
         },
         headers: default_headers
    flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    # Verify pt parameter is preserved in redirect
    assert_response :redirect
    signed_rt = Rack::Utils.parse_nested_query(URI.parse(response.location).query)["pt"]

    assert_nil signed_rt

    # Extract email ID from redirect location
    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)

    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
        notification.fetch(:params).fetch(:public_id) == user_email.public_id
      end
    notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
    correct_code = OutboundSensitivePayload.decrypt_email_otp(notification.fetch(:params).fetch(:encrypted_hotp_token))

    # Submit correct OTP with pt parameter
    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
          params: {
            "cf-turnstile-response" => "test",
            :id => user_email.id,
            :user_email => {
              pass_code: correct_code,
            },
            :pt => signed_rt,
          },
          headers: default_headers

    # Should redirect directly to the decoded pt destination
    assert_redirected_to auth_app_sign_up_check_email_birthdate_path(ri: "jp", fb: flow_binding)
  end

  # Transaction Tests for Client Creation

  test "successful OTP verification creates user and saves email in transaction" do
    flow_binding = nil
    email = "transaction_success@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
      flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    end

    # Extract email ID from redirect location
    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)
    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
        notification.fetch(:params).fetch(:public_id) == user_email.public_id
      end
    notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
    correct_code = OutboundSensitivePayload.decrypt_email_otp(notification.fetch(:params).fetch(:encrypted_hotp_token))

    initial_user_count = Client.count

    # Submit correct OTP
    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
          params: {
            "cf-turnstile-response" => "test",
            :id => user_email.id,
            :user_email => {
              pass_code: correct_code,
            },
          },
          headers: default_headers

    # Verify success response
    assert_redirected_to auth_app_sign_up_check_email_birthdate_path(ri: "jp", fb: flow_binding)

    # Verify Client count unchanged (pending user was updated, not created)
    assert_equal initial_user_count, Client.count

    # Verify ClientEmail was updated and linked to user
    user_email.reload

    assert_not_nil user_email.user_id
    assert_equal ClientEmailStatus::VERIFIED_WITH_SIGN_UP, user_email.user_email_status_id

    # Verify Client has correct status
    user = user_email.user

    assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, user.status_id
    assert_nil user.rp_account
  end

  test "successful OTP verification creates audit log in transaction" do
    flow_binding = nil
    email = "audit_log_test@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
      flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    end

    # Extract email ID from redirect location
    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)
    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
        notification.fetch(:params).fetch(:public_id) == user_email.public_id
      end
    notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
    correct_code = OutboundSensitivePayload.decrypt_email_otp(notification.fetch(:params).fetch(:encrypted_hotp_token))

    initial_audit_count = ClientChronicle.count

    # Submit correct OTP
    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
          params: {
            "cf-turnstile-response" => "test",
            :id => user_email.id,
            :user_email => {
              pass_code: correct_code,
            },
          },
          headers: default_headers

    # Verify success response
    assert_redirected_to auth_app_sign_up_check_email_birthdate_path(ri: "jp", fb: flow_binding)

    # Sign-up completion and sign-in audit are delayed until checkpoint finalization.
    assert_equal initial_audit_count, ClientChronicle.count
  end

  test "successful OTP verification does not write signup audit before finalization" do
    email = "missing_audit_event_signup@example.com"

    initial_audit_count = ClientChronicle.count

    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers
    flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)
    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
        notification.fetch(:params).fetch(:public_id) == user_email.public_id
      end
    notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
    correct_code = OutboundSensitivePayload.decrypt_email_otp(notification.fetch(:params).fetch(:encrypted_hotp_token))

    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
          params: {
            "cf-turnstile-response" => "test",
            :id => user_email.id,
            :user_email => {
              pass_code: correct_code,
            },
          },
          headers: default_headers

    assert_redirected_to auth_app_sign_up_check_email_birthdate_path(ri: "jp", fb: flow_binding)
    assert_equal initial_audit_count, ClientChronicle.count
  end

  test "sets user session after successful registration" do
    flow_binding = nil
    email = "session_set@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
      flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    end

    # Extract email ID from redirect location
    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)
    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
        notification.fetch(:params).fetch(:public_id) == user_email.public_id
      end
    notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
    correct_code = OutboundSensitivePayload.decrypt_email_otp(notification.fetch(:params).fetch(:encrypted_hotp_token))

    # Submit correct OTP
    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
          params: {
            "cf-turnstile-response" => "test",
            :id => user_email.id,
            :user_email => {
              pass_code: correct_code,
            },
          },
          headers: default_headers

    # No authenticated session is issued before checkpoint finalization.
    assert_nil cookies[::AuthenticationClient::ACCESS_COOKIE_KEY]

    # Verify user and token were created
    user = user_email.reload.user

    assert_not_nil user, "Pending client should exist"
    assert_not ClientToken.exists?(user_id: user.id), "Client token should not be created before finalization"
  end

  test "successful registration does not set auth cookies before finalization" do
    email = "cookie_domain_up_#{SecureRandom.hex(4)}@example.com"

    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers
    flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by!(public_id: email_id)
    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
        notification.fetch(:params).fetch(:public_id) == user_email.public_id
      end
    notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
    pass_code = OutboundSensitivePayload.decrypt_email_otp(notification.fetch(:params).fetch(:encrypted_hotp_token))

    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
          params: {
            "cf-turnstile-response" => "test",
            :id => user_email.id,
            :user_email => {
              pass_code: pass_code,
            },
          },
          headers: default_headers

    set_cookie = response.headers["Set-Cookie"].to_s

    assert_no_match(/#{Regexp.escape(::AuthenticationClient::ACCESS_COOKIE_KEY.to_s)}=/, set_cookie)
  end

  test "Auth email signup finalizes its binding and hands verified login evidence to Base without issuing a root" do
    email = "finalize_app_email_#{SecureRandom.hex(4)}@example.com"

    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers
    flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    assert_response :redirect
    user_email = ClientEmail.order(:created_at).last
    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
        notification.fetch(:params).fetch(:public_id) == user_email.public_id
      end
    notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
    pass_code = OutboundSensitivePayload.decrypt_email_otp(notification.fetch(:params).fetch(:encrypted_hotp_token))

    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
          params: { user_email: { pass_code: pass_code } },
          headers: default_headers

    assert_redirected_to auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding)

    get auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding), headers: default_headers

    assert_response :ok
    assert_equal "auth/app/sign/up/checkpoints/show", inertia_component
    birthdate = inertia_props.fetch("birthdate")

    assert_equal "iso", birthdate.fetch("fields").fetch("format")
    assert_equal(
      %w(year month day),
      birthdate.fetch("fields").fetch("parts").map { |part| part.fetch("part") },
    )
    birthdate_path = auth_app_sign_up_check_email_birthdate_path(ri: "jp", fb: flow_binding)

    assert_equal birthdate_path, birthdate.fetch("action")
    cancellation_path = auth_app_sign_up_check_email_birthdate_path(ri: "jp", fb: flow_binding)

    assert_equal cancellation_path, inertia_props.fetch("cancellation").fetch("action")
    # The auth surface carries no header navigation to sign-up/sign-in on any page, so a checkpoint
    # offers no escape hatch without needing a per-page suppression flag.
    assert_not inertia_props.fetch("chrome").key?("primary_navigation")

    get auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding), headers: default_headers

    assert_response :ok
    assert_equal "iso", inertia_props.fetch("birthdate").fetch("fields").fetch("format")

    cycle = current_sign_up_flow(user_email)

    patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding),
          params: {
            requirement: "birthdate",
            birthdate: "2000-01-01",
            checkpoint_version: cycle.reload.checkpoint_version,
          },
          headers: default_headers

    assert_response :redirect
    uri = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), uri.host
    assert_equal URI.parse(auth_app_sign_in_check_path(ri: "jp")).path, URI.parse(response.location).path

    user = user_email.reload.user

    assert_equal ClientSignUpFlowStatus::COMPLETED, cycle.reload.status_id
    assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, user.status_id
    assert_equal 0, ClientToken.where(user_id: user.id).count
    assert_predicate user_email, :binding_effective?
    follow_redirect!

    assert_response :redirect
    assert_equal auth_app_sign_handoff_path(ri: "jp"), URI.parse(response.location).request_uri
    follow_redirect!

    assert_response :success
    form = response.parsed_body.at_css("form")
    csrf = form.at_css('input[name="authenticity_token"]')["value"]
    post form["action"],
         params: { authenticity_token: csrf },
         headers: { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin" }

    assert_response :see_other
    continuation = URI.parse(response.location)

    assert_equal "https", continuation.scheme
    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL"), continuation.host
    assert_equal URI.parse(base_app_sign_completion_url(ri: "jp")).path, continuation.path
    query = Rack::Utils.parse_query(continuation.query)

    assert_equal %w(result_ref ri transaction_ref), query.keys.sort
    parent = ClientSignInFlow.find_by!(public_id: query.fetch("transaction_ref"))

    assert_equal user.id, parent.principal_id
    assert_equal "email", parent.authentication_method
    assert_predicate parent, :sign_in_session_issuance_pending?
    assert_equal 0, ClientToken.where(user_id: user.id).count
  end

  test "OTP data is cleared after successful verification" do
    flow_binding = nil
    email = "otp_clear@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
      flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    end

    # Extract email ID from redirect location
    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)
    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
        notification.fetch(:params).fetch(:public_id) == user_email.public_id
      end
    notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
    correct_code = OutboundSensitivePayload.decrypt_email_otp(notification.fetch(:params).fetch(:encrypted_hotp_token))

    # Verify OTP data exists before verification
    transaction = ClientEmailCeremonyTransaction.where(
      operation: "sign_up",
      email_candidate_ref: user_email.public_id,
    ).sole

    assert_predicate transaction.otp_verifier, :present?
    assert_nil transaction.otp_consumed_at

    # Submit correct OTP
    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
          params: {
            "cf-turnstile-response" => "test",
            :id => user_email.id,
            :user_email => {
              pass_code: correct_code,
            },
          },
          headers: default_headers

    # Verify OTP data was cleared
    user_email.reload

    assert_equal ClientEmailStatus::VERIFIED_WITH_SIGN_UP, user_email.user_email_status_id
    assert_nil transaction.reload.otp_verifier
    assert transaction.otp_consumed_at
  end

  test "does not reset session ID before checkpoint finalization" do
    flow_binding = nil
    email = "session_reset_test@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
      flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    end

    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)
    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
        notification.fetch(:params).fetch(:public_id) == user_email.public_id
      end
    notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
    correct_code = OutboundSensitivePayload.decrypt_email_otp(notification.fetch(:params).fetch(:encrypted_hotp_token))

    old_session_id = session.id.to_s

    # Submit correct OTP
    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
          params: {
            "cf-turnstile-response" => "test",
            :id => user_email.id,
            :user_email => {
              pass_code: correct_code,
            },
          },
          headers: default_headers

    assert_equal old_session_id, session.id.to_s
  end

  test "creates pending user with UNVERIFIED_WITH_SIGN_UP status during email registration" do
    email = "pending_user_test@example.com"

    initial_user_count = Client.count

    # Create registration record
    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    # Verify pending user was created
    assert_equal initial_user_count + 1, Client.count

    # Extract email and verify it's linked to a pending user
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)

    assert_not_nil user_email.user
    assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, user_email.user.status_id
    assert_equal ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, user_email.user_email_status_id
  end

  test "create binds email signup cycle and otp success advances to guardrail" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "email_cycle_#{SecureRandom.hex(4)}@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers
    flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    assert_response :redirect

    user_email = ClientEmail.order(:created_at).last
    cycle = current_sign_up_flow(user_email)

    assert_equal "email", cycle.entry_method
    assert_equal "email", cycle.pending_contact_type
    assert_equal user_email.id, cycle.pending_contact_id
    assert_equal user_email.user_id, cycle.principal_id
    assert_equal "contact", cycle.step

    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
        notification.fetch(:params).fetch(:public_id) == user_email.public_id
      end
    notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
    pass_code = OutboundSensitivePayload.decrypt_email_otp(notification.fetch(:params).fetch(:encrypted_hotp_token))

    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
          params: {
            "cf-turnstile-response" => "test",
            :user_email => { pass_code: pass_code },
          },
          headers: default_headers

    assert_redirected_to auth_app_sign_up_check_email_birthdate_path(ri: "jp", fb: flow_binding)
    assert_equal "checkpoint", cycle.reload.step
  end

  test "email signup checkpoint persists birthdate requirement" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "email_birthdate_#{SecureRandom.hex(4)}@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers
    flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    # Follow the redirect to the OTP page to consume the "OTP sent" flash notice
    # set by the create action; otherwise it leaks into the PATCH assertion below.
    follow_redirect!

    user_email = ClientEmail.order(:created_at).last
    cycle = current_sign_up_flow(user_email)
    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
        notification.fetch(:params).fetch(:public_id) == user_email.public_id
      end
    notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
    pass_code = OutboundSensitivePayload.decrypt_email_otp(notification.fetch(:params).fetch(:encrypted_hotp_token))

    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
          params: {
            "cf-turnstile-response" => "test",
            :user_email => { pass_code: pass_code },
          },
          headers: default_headers

    assert_redirected_to auth_app_sign_up_check_email_birthdate_path(ri: "jp", fb: flow_binding)
    assert_nil flash[:notice]

    get auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding), headers: default_headers

    assert_response :success
    assert_equal "iso", inertia_props.fetch("birthdate").fetch("fields").fetch("format")

    patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding),
          params: {
            requirement: "birthdate",
            birthdate_year: "2000",
            birthdate_month: "02",
            birthdate_day: "03",
            checkpoint_version: cycle.reload.checkpoint_version,
          },
          headers: default_headers

    assert_response :redirect
    assert_equal "2000-02-03", user_email.user.reload.birthdate
    assert cycle.reload.requirement_cleared?(:birthdate)
    assert_equal ClientSignUpFlowStatus::COMPLETED, cycle.status_id
  end

  test "duplicate email signup birthdate submission renders base completion and completes there" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           client_email: {
             raw_address: "email_birthdate_duplicate_#{SecureRandom.hex(4)}@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers
    flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    user_email = ClientEmail.order(:created_at).last
    cycle = current_sign_up_flow(user_email)
    pass_code = otp_code_for(user_email)

    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
          params: {
            "cf-turnstile-response" => "test",
            :user_email => { pass_code: pass_code },
          },
          headers: default_headers

    assert_redirected_to auth_app_sign_up_check_email_birthdate_path(ri: "jp", fb: flow_binding)

    birthdate_params = {
      requirement: "birthdate",
      birthdate_year: "2000",
      birthdate_month: "02",
      birthdate_day: "03",
      checkpoint_version: cycle.reload.checkpoint_version,
    }

    patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding),
          params: birthdate_params,
          headers: default_headers

    assert_response :redirect
    uri = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), uri.host
    assert_equal URI.parse(auth_app_sign_in_check_path(ri: "jp")).path, URI.parse(response.location).path
    assert_equal ClientSignUpFlowStatus::COMPLETED, cycle.reload.status_id
    committed_flow = cycle.attributes
    committed_contact = user_email.reload.attributes

    patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding),
          params: birthdate_params,
          headers: default_headers

    assert_response :conflict
    assert_equal I18n.t("errors.messages.phase_violation_refused", locale: :ja), response.body
    retained_facts = committed_flow == cycle.reload.attributes && committed_contact == user_email.reload.attributes

    assert retained_facts, "terminal checkpoint replay must preserve committed facts"
    assert_equal ClientSignUpFlowStatus::COMPLETED, cycle.reload.status_id
  end

  test "email signup checkpoint cancel stops the signup path" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "email_checkpoint_cancel_#{SecureRandom.hex(4)}@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers
    flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    user_email = ClientEmail.order(:created_at).last
    cycle = current_sign_up_flow(user_email)
    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
        notification.fetch(:params).fetch(:public_id) == user_email.public_id
      end
    notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
    pass_code = OutboundSensitivePayload.decrypt_email_otp(notification.fetch(:params).fetch(:encrypted_hotp_token))

    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
          params: { user_email: { pass_code: pass_code } },
          headers: default_headers

    get auth_app_sign_up_guard_email_url(ri: "jp"), headers: default_headers
    get auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding), headers: default_headers

    assert_response :success

    delete auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding), headers: default_headers

    assert_redirected_to auth_app_sign_up_url(ri: "jp")
    assert_equal ClientSignUpFlowStatus::CANCELLED, cycle.reload.status_id
    cancelled_flow = cycle.attributes

    get auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding), headers: default_headers

    assert_response :conflict
    assert_equal I18n.t("errors.messages.phase_violation_refused", locale: :ja), response.body
    assert_equal cancelled_flow, cycle.reload.attributes
  end

  test "completed ISO birthdate checkpoint refuses replay without changing its committed proof" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "email_birthdate_retry_#{SecureRandom.hex(4)}@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers
    flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    user_email = ClientEmail.order(:created_at).last
    cycle = current_sign_up_flow(user_email)
    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
        notification.fetch(:params).fetch(:public_id) == user_email.public_id
      end
    notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
    pass_code = OutboundSensitivePayload.decrypt_email_otp(notification.fetch(:params).fetch(:encrypted_hotp_token))

    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
          params: { user_email: { pass_code: pass_code } },
          headers: default_headers

    get auth_app_sign_up_guard_email_url(ri: "jp"), headers: default_headers
    get auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding), headers: default_headers

    submission = {
      requirement: "birthdate", birthdate: "2000-02-03", checkpoint_version: cycle.reload.checkpoint_version,
    }
    patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding),
          params: submission,
          headers: default_headers

    assert_response :redirect
    assert_equal ClientSignUpFlowStatus::COMPLETED, cycle.reload.status_id
    assert cycle.requirement_cleared?(:birthdate)
    committed_flow = cycle.attributes
    committed_contact = user_email.reload.attributes

    patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding),
          params: submission, headers: default_headers

    assert_response :conflict
    retained_facts = committed_flow == cycle.reload.attributes && committed_contact == user_email.reload.attributes

    assert retained_facts, "replay must retain the original committed checkpoint and binding"
  end

  test "leap-day under-thirteen signup halts without changing the Ticket clock" do
    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "email_under13_#{SecureRandom.hex(4)}@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers
    flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    assert_response :redirect
    user_email = ClientEmail.order(:created_at).last
    cycle = current_sign_up_flow(user_email)
    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
        notification.fetch(:params).fetch(:public_id) == user_email.public_id
      end
    notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
    pass_code = OutboundSensitivePayload.decrypt_email_otp(notification.fetch(:params).fetch(:encrypted_hotp_token))

    patch auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding),
          params: { :user_email => { pass_code: pass_code }, "cf-turnstile-response" => "test" },
          headers: default_headers

    assert_redirected_to auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding)

    travel_to Time.zone.local(2024, 2, 29, 12, 0, 0) do
      get auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding), headers: default_headers

      assert_response :success

      patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding),
            params: {
              requirement: "birthdate",
              birthdate: "2011-03-01",
              checkpoint_version: cycle.reload.checkpoint_version,
            },
            headers: default_headers

      assert_response :success
      assert_includes response.body, "この登録方法ではアカウントを作成できません"
      assert_equal ClientSignUpFlowStatus::HALTED, cycle.reload.status_id

      patch auth_app_sign_up_check_email_birthdate_url(ri: "jp", fb: flow_binding),
            params: {
              requirement: "birthdate",
              birthdate: "2000-01-01",
              checkpoint_version: cycle.checkpoint_version,
            },
            headers: default_headers

      # The age-restricted session state keeps blocking the retry instead of restarting sign-up.
      assert_response :success
      assert_includes response.body, "この登録方法ではアカウントを作成できません"
      assert_equal ClientSignUpFlowStatus::HALTED, cycle.reload.status_id
      assert_not cycle.requirement_cleared?(:birthdate)
    end
  end

  test "does not leave zero or null user_id in database" do
    email = "no_zero_user_id@example.com"

    # Create registration record
    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    # Extract email ID from redirect location
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)

    # Verify user_id is not zero or null
    assert_not_nil user_email.user_id, "user_id should not be nil"
    assert_not_equal "00000000-0000-0000-0000-000000000000", user_email.user_id,
                     "user_id should not be zero UUID"

    # Verify user actually exists
    assert Client.exists?(id: user_email.user_id), "Client record should exist for user_id"
  end

  test "replacing an owned pending email retains the halted flow and schedules its artifacts for purge" do
    email = "replace_pending_test@example.com"

    # First registration attempt
    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    # Get first pending user
    first_email_id = ClientEmail.order(:created_at).last.public_id
    first_email = ClientEmail.find_by(public_id: first_email_id)
    first_user_id = first_email.user_id
    first_flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))

    # Count users before second attempt
    user_count_before_second = Client.count

    # Second registration attempt after cooldown (should delete first pending user)
    decision_time = first_email.otp_last_sent_at + EmailOtpPolicy::SEND_COOLDOWN + 1.second
    ClientEmail.stub(:database_now, decision_time) do
      travel EmailOtpPolicy::SEND_COOLDOWN + 1.second do
        post auth_app_sign_up_email_url(ri: "jp"),
             params: {
               user_email: {
                 raw_address: email,
                 confirm_policy: "1",
               },
               "cf-turnstile-response": "test",
             },
             headers: default_headers
      end

      assert_response :redirect

      retained_owner = Client.find(first_user_id)

      assert_equal ClientSignUpFlowStatus::HALTED, first_flow.reload.status_id
      assert_predicate first_flow, :cleanup_completed?
      assert_operator retained_owner.discard_at, :<=, first_flow.cleanup_completed_at
      assert_operator retained_owner.purge_eligible_at, :>, retained_owner.discard_at
      assert_operator first_email.reload.discard_at, :<=, first_flow.cleanup_completed_at
      assert_equal first_user_id, first_email.user_id
      assert_equal user_count_before_second + 1, Client.count

      # Verify new email has a different user
      second_email_id = ClientEmail.order(:created_at).last.public_id
      second_email = ClientEmail.find_by(public_id: second_email_id)

      assert_not_equal first_user_id, second_email.user_id
      assert_not_nil second_email.user
    end
  end

  test "can abandon first email and register with a different email without error" do
    first_email = "first_abandoned@example.com"
    second_email = "second_attempt@example.com"

    # First registration attempt with email A
    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: first_email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    # Get first pending user info
    first_email_id = ClientEmail.order(:created_at).last.public_id
    first_record = ClientEmail.find_by(public_id: first_email_id)
    first_user_id = first_record.user_id

    assert_not_nil first_record
    assert_equal ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, first_record.user_email_status_id

    # Client abandons: navigates back to "new" page
    # This should succeed without redirect loop or error
    get new_auth_app_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success

    # Client submits a different email B
    post auth_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: second_email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    # Verify second registration created a new pending user
    second_email_id = ClientEmail.order(:created_at).last.public_id
    second_record = ClientEmail.find_by(public_id: second_email_id)

    assert_not_nil second_record
    assert_equal ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, second_record.user_email_status_id
    assert_not_equal first_user_id, second_record.user_id

    retained_owner = Client.find(first_user_id)

    assert_operator retained_owner.discard_at, :<=, Time.current
    assert_operator retained_owner.purge_eligible_at, :>, retained_owner.discard_at
    assert_operator first_record.reload.discard_at, :<=, Time.current
    assert_equal first_user_id, first_record.user_id
  end

  # OTP Resend Cooldown Tests
  test "create keeps re-registration inside overwrite window non-disclosing" do
    email = "cooldown_test@example.com"

    # First registration attempt
    assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :redirect

    first_flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
    first_candidate = ClientEmail.find(first_flow.pending_contact_id)

    assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    replacement_flow = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
    replacement = ClientEmail.find(replacement_flow.pending_contact_id)

    assert_redirected_to auth_app_sign_up_check_email_otp_url(ri: "jp", fb: flow_binding)
    assert_equal replacement_flow.public_id, SignFlowBindingCodec.decode(flow_binding).flow_public_id
    assert_not_equal first_candidate.id, replacement.id
    assert_not_equal first_candidate.user_id, replacement.user_id
    assert_equal ClientSignUpFlowStatus::HALTED, first_flow.reload.status_id
    assert_predicate first_flow, :cleanup_completed?
    assert_equal email, replacement.address
    assert_nil replacement.binding_finalized_at
  end

  test "create allows re-registration after overwrite window expires for new signup" do
    email = "cooldown_expire_test@example.com"

    # First registration attempt
    assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :redirect

    # After the overwrite window expires, even though OTP resend cooldown is longer.
    first_email = ClientEmail.order(:created_at).last
    decision_time = first_email.otp_last_sent_at + EmailOtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second
    ClientEmail.stub(:database_now, decision_time) do
      travel EmailOtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second do
        assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
          post auth_app_sign_up_email_url(ri: "jp"),
               params: {
                 user_email: {
                   raw_address: email,
                   confirm_policy: "1",
                 },
                 "cf-turnstile-response": "test",
               },
               headers: default_headers
        end

        assert_response :redirect
      end
    end
  end

  test "existing registered emails show otp page instead of entering cooldown" do
    user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
    existing_email = ClientEmail.create!(
      user: user,
      address: "registered_cooldown@example.com",
      confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      binding_finalized_at: ClientEmail.database_now,
    )
    original_contact_facts = existing_email.reload.attributes
    original_owner_facts = user.reload.attributes

    assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "registered_cooldown@example.com",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :redirect
    first_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    assert_redirected_to auth_app_sign_up_check_email_otp_url(ri: "jp", fb: first_binding)

    assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "registered_cooldown@example.com",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :redirect
    second_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    assert_redirected_to auth_app_sign_up_check_email_otp_url(ri: "jp", fb: second_binding)
    assert_not_equal first_binding, second_binding
    assert_withheld("effective contact facts remain unchanged") {
      original_contact_facts == existing_email.reload.attributes
    }
    assert_withheld("effective owner facts remain unchanged") { original_owner_facts == user.reload.attributes }
  end

  test "otp_resend_too_soon i18n key exists in both locales" do
    assert_not_nil I18n.t("sign.app.registration.email.create.otp_resend_too_soon", locale: :ja, default: nil)
    assert_not_nil I18n.t("sign.app.registration.email.create.otp_resend_too_soon", locale: :en, default: nil)
  end

  test "create rejects signup for an email blocked by an in-force registration_blocked Identifier Effect, " \
       "sending no OTP" do
    operator = operators(:one)
    the_case = AppEnforcementCase.new(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "visible",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: "some_prior_client_public_id",
      applied_by_operator_public_id: operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_email(realm: "app", value: "enforcement_blocked@example.com")
    the_case.identifier_effects.build(**digest, registration_blocked: true, effective_at: Time.current)
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    assert_enqueued_jobs 0, only: OtpNotifierEmailDeliveryJob do
      post auth_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "Enforcement_Blocked@Example.com",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("errors"), I18n.t("sign.app.registration.email.create.address_required")
    assert_not ClientEmail.exists?(
      address_digest: IdentifierBlindIndex.bidx_for_email("enforcement_blocked@example.com", realm: :app),
    )
  end

  private

  def default_headers
    { "Host" => host, "HTTPS" => "on", "X-CSRF-Token" => csrf_token_value }
  end

  def reset_cookie_jar!
    cookies.to_hash.each_key { |key| cookies.delete(key) }
  end

  def start_sign_up_flow!(email)
    post(
      auth_app_sign_up_email_url(ri: "jp"),
      params: {
        user_email: { raw_address: email, confirm_policy: "1" },
        "cf-turnstile-response": "test",
      },
      headers: default_headers,
    )
    ClientEmail.order(:created_at).last
  end

  def current_sign_up_flow(user_email)
    ClientSignUpFlow.order(:id).find_by(
      principal_id: user_email.user_id,
      pending_contact_type: "email",
      pending_contact_id: user_email.id,
    ) || ClientSignUpFlow.order(:id).find_by!(
      principal_id: user_email.user_id,
      pending_contact_type: "email",
    )
  end

  def otp_code_for(user_email)
    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
        notification.fetch(:params).fetch(:public_id) == user_email.public_id
      end
    notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
    OutboundSensitivePayload.decrypt_email_otp(notification.fetch(:params).fetch(:encrypted_hotp_token))
  end

  def host
    ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
  end
  private
end

# DAMP auth header helpers for this test class.
class Auth::App::Sign::Up::EmailsControllerTest
  private
end

# DAMP local helper copy for former shared test support.
class Auth::App::Sign::Up::EmailsControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
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
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
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
    user = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
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

  def insert_verified_visitor_email!(visitor_id:, address:)
    VisitorEmail.insert_all(
      [
        {
          visitor_id: visitor_id,
          address: address,
          address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :com),
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          otp_attempts_count: 0,
          public_id: SecureRandom.alphanumeric(21),
          created_at: Time.current,
          updated_at: Time.current,
        },
      ],
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

  def satisfy_visitor_verification(token, scope: nil)
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    when "VisitorToken" then "step_up:com"
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
class Auth::App::Sign::Up::EmailsControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

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

  def with_preference_jwt_keys(host: nil)
    audiences = host ? [host] : PreferenceJwtConfiguration.audiences
    pub_key_for_stub = ->(_kid, **_options) { self.class::PREFERENCE_JWT_KEY }
    PreferenceJwtConfiguration.stub(:private_key, self.class::PREFERENCE_JWT_KEY) do
      PreferenceJwtConfiguration.stub(:public_key, self.class::PREFERENCE_JWT_KEY) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, self.class::PREFERENCE_JWT_KEY) do
          PreferenceJwtConfiguration.stub(:public_key_for, pub_key_for_stub) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, audiences) { yield }
              end
            end
          end
        end
      end
    end
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

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address, realm: :com),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
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
    %w(AUTH_APP AUTH_ORG AUTH_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
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
