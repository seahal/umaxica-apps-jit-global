# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::Sign::In::EmailsControllerTest < ActionDispatch::IntegrationTest
  counts_rate_limits!
  fixtures :clients, :operators, :client_statuses, :operator_statuses, :client_email_statuses

  include ActiveSupport::Testing::TimeHelpers

  test "should get new" do
    get new_auth_app_sign_in_email_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success

    assert_equal "auth/app/sign/in/emails/new", inertia_component
    assert_equal I18n.t("sign.app.authentication.email.new.page_title"), inertia_props.fetch("title")

    assert_predicate inertia_props.fetch("back_link").fetch("href"), :present?

    assert_nil cookies[:htop_private_key]
    #    assert_select "a[href=?]",
    #                  new_auth_app_authentication_path(query, ri: "jp"),
    #                  I18n.t("sign.app.authentication.new.back")
    assert_response :success
  end

  test "reject already logged in user" do
    user = clients(:one)
    get new_auth_app_sign_in_email_url(ri: "jp"),
        headers: as_user_headers(user, host: @host)

    assert_response :bad_request
    assert_includes response.body, I18n.t("sign.app.authentication.email.new.you_have_already_logged_in")
  end

  test "reject already logged in staff" do
    staff = operators(:one)
    get new_auth_app_sign_in_email_url(ri: "jp"),
        headers: { "Host" => @host, "X-TEST-CURRENT-STAFF" => staff.id }

    assert_response :success
    # assert_equal I18n.t("sign.app.authentication.email.new.you_have_already_logged_in"), response.body
  end
  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    ActionMailer::Base.deliveries.clear
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    @original_login_cooldown = login_cooldown
    self.login_cooldown = 0.seconds
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_queue_adapter
    self.login_cooldown = @original_login_cooldown
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "GET new displays email form" do
    get new_auth_app_sign_in_email_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success
    assert_equal "client_email[address]", inertia_props.fetch("form").fetch("address_field").fetch("name")
  end

  test "POST create without valid email redirects (enumeration protection)" do
    post auth_app_sign_in_email_url(ri: "jp"),
         params: { user_email: { address: "nonexistent@example.com" } },
         headers: { "Host" => @host }

    # Should redirect to edit to prevent enumeration
    assert_response :found
    assert_redirected_to %r{/sign/in/email/edit}
    assert_nil SignAppInEmailAuthenticationState.load(session)&.id
  end

  test "POST create accepts the form scope used by the sign-in page" do
    user = clients(:one)
    email = user.client_emails.create!(address: "scope_test_#{SecureRandom.hex(4)}@example.com")

    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :client_email => { address: email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found
    assert_redirected_to %r{/sign/in/email/edit}
    assert_equal email.id, SignAppInEmailAuthenticationState.load(session)&.id
  end

  test "POST create responds the same for existing and missing emails" do
    user = clients(:one)
    existing_email = user.client_emails.create!(address: "enum_test@example.com")

    existing_session = open_session
    existing_session.post(
      auth_app_sign_in_email_url(ri: "jp"),
      params: { user_email: { address: existing_email.address } },
      headers: { "Host" => @host },
    )

    missing_session = open_session
    missing_session.post(
      auth_app_sign_in_email_url(ri: "jp"),
      params: { user_email: { address: "missing-enum@example.com" } },
      headers: { "Host" => @host },
    )

    assert_equal existing_session.response.status, missing_session.response.status
    assert_equal existing_session.response.location, missing_session.response.location
    assert_equal existing_session.response.body, missing_session.response.body

    if existing_session.flash[:notice].nil?
      assert_nil missing_session.flash[:notice]
    else
      assert_equal existing_session.flash[:notice], missing_session.flash[:notice]
    end
  end

  test "POST create with existing email generates OTP and redirects to edit" do
    # Create a test email in the database
    user = clients(:one)
    test_email = "auth_test_#{SecureRandom.hex(4)}@example.com"
    user.client_emails.create!(address: test_email)

    # Make the POST request with valid email and Turnstile response
    # Turnstile is automatically mocked to return true in test environment
    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found
    assert_redirected_to %r{/sign/in/email/edit}

    follow_redirect!
    follow_redirect! if response.redirect?

    assert_response :success
    assert_equal "auth/app/sign/in/emails/edit", inertia_component

    form = inertia_props.fetch("form")
    pass_code_field = form.fetch("pass_code_field")

    assert_equal I18n.t("sign.app.authentication.email.edit.submit"), form.fetch("submit_label")
    assert_equal I18n.t("sign.app.authentication.email.edit.page_title"), inertia_props.fetch("title")
    assert_equal I18n.t("sign.app.authentication.email.edit.code_label"), pass_code_field.fetch("label")
    assert_equal I18n.t("sign.app.authentication.email.edit.code_placeholder"),
                 pass_code_field.fetch("placeholder")
    assert_equal "client_email[pass_code]", pass_code_field.fetch("name")
    assert_equal "one-time-code", pass_code_field.fetch("autocomplete")
    assert_includes inertia_props.fetch("description"), "メールアドレス"
    assert_equal I18n.t("sign.app.authentication.email.edit.delivery_help"),
                 inertia_props.fetch("delivery_help")
  end

  test "timing attack protection in update action" do
    # Create and verify an email
    user = clients(:one)
    test_email = user.client_emails.create!(address: "timing_test@example.com")
    test_email.update!(pass_code: "123456", otp_attempts_count: 0)

    # Start session
    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    follow_redirect!
    session_id = cookies["user_email_authentication_id"]

    # Measure time for valid code
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: "123456" } },
          headers: { "Host" => @host, "Cookie" => "user_email_authentication_id=#{session_id}" }
    valid_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    # Reset for invalid code test
    test_email.update!(pass_code: "123456", otp_attempts_count: 0)
    travel CommonOtpPolicy::SEND_COOLDOWN + 1.second do
      post auth_app_sign_in_email_url(ri: "jp"),
           params: {
             :user_email => { address: test_email.address },
             "cf-turnstile-response" => "test_token",
           },
           headers: { "Host" => @host }
    end

    follow_redirect!
    session_id = cookies["user_email_authentication_id"]

    # Measure time for invalid code
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: "999999" } },
          headers: { "Host" => @host, "Cookie" => "user_email_authentication_id=#{session_id}" }
    invalid_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    # Times should be similar (within 50% tolerance for timing attack protection)
    time_difference = (valid_time - invalid_time).abs
    max_allowed_difference = [valid_time, invalid_time].max * 1

    assert_operator time_difference, :<=, max_allowed_difference,
                    "Response times differ too much: valid=#{valid_time.round(4)}s, invalid=#{invalid_time.round(4)}s"
  end

  # Turnstile Widget Verification Tests
  test "new authentication email page renders Turnstile widget" do
    get new_auth_app_sign_in_email_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success
    # The widget is drawn by the client from this configuration; the site key is public by design
    # and the secret key with it the token verification stay server side.
    assert_equal "render", inertia_props.fetch("turnstile").fetch("mode")
    assert_predicate inertia_props.fetch("turnstile").fetch("site_key"), :present?
  end

  # Login Tests

  test "successful OTP verification redirects to dashboard" do
    # Create email with user association
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "login_test_#{SecureRandom.hex(4)}@example.com",
    )

    # Start authentication process to trigger email discovery
    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found
    assert_equal test_email.id, SignAppInEmailAuthenticationState.load(session)&.id

    # Generate valid OTP code
    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    hotp = ROTP::HOTP.new(otp_private_key)
    valid_pass_code = hotp.at(otp_counter).to_s

    # Store OTP on the email manually (bypasses application logic)
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    # Verify OTP to log in
    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: valid_pass_code } },
          headers: { "Host" => @host }

    assert_response :found
    assert_redirected_to auth_app_sign_in_check_path(ri: "jp")

    cycle = ClientSignInFlow.where(principal_id: user.id).recent_first.first

    assert_equal "CHECKPOINT_PENDING", cycle.state
    assert_equal cycle.public_id, session.dig(:app_sign_in_flow_locator, "public_id")
  end

  test "post create is refused while the record-level otp cooldown is still running" do
    user = clients(:one)
    test_email = user.client_emails.create!(address: "otp_cooldown_#{SecureRandom.hex(4)}@example.com")
    test_email.update!(otp_last_sent_at: Time.current)

    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :too_many_requests
    assert_equal I18n.t("sign.app.authentication.email.create.cooldown"), response.body
  end

  test "post create is refused when the user already holds a restricted session at the limit" do
    # A fixture user carries sessions of its own, and the model refuses a fourth row
    # outright; start from a user whose whole session list is the one built here.
    user = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    test_email = user.client_emails.create!(address: "session_limit_#{SecureRandom.hex(4)}@example.com")
    ClientToken::MAX_SESSIONS_PER_USER.times do
      ClientToken.create!(
        user: user,
        user_token_status_id: ClientTokenStatus::ACTIVE,
        user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      )
    end
    ClientToken.create!(
      user: user,
      user_token_status_id: ClientTokenStatus::RESTRICTED,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )

    assert_no_difference -> { ActionMailer::Base.deliveries.count } do
      post auth_app_sign_in_email_url(ri: "jp"),
           params: {
             :user_email => { address: test_email.address },
             "cf-turnstile-response" => "test_token",
           },
           headers: { "Host" => @host }
    end

    assert_response :forbidden
    assert_equal I18n.t("session_limit.login_limit_exceeded"), response.body
  end

  test "patch update after an unknown address is rejected without disclosing that no account exists" do
    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: "no-such-user-#{SecureRandom.hex(4)}@example.com" },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found
    assert_nil SignAppInEmailAuthenticationState.load(session)&.id

    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: "123456" } },
          headers: { "Host" => @host }

    assert_response :unprocessable_content
    assert_equal "auth/app/sign/in/emails/edit", inertia_component
  end

  test "patch update is rejected when the account stopped allowing login after the code was sent" do
    user = clients(:one)
    test_email = user.client_emails.create!(address: "blocked_#{SecureRandom.hex(4)}@example.com")

    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found
    assert_equal test_email.id, SignAppInEmailAuthenticationState.load(session)&.id

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)
    user.update!(status_id: ClientStatus::RESERVED)

    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: ROTP::HOTP.new(otp_private_key).at(otp_counter).to_s } },
          headers: { "Host" => @host }

    assert_response :unprocessable_content
    assert_equal "auth/app/sign/in/emails/edit", inertia_component
  end

  test "patch update with a malformed pass code answers json requests with the error body" do
    user = clients(:one)
    test_email = user.client_emails.create!(address: "json_invalid_#{SecureRandom.hex(4)}@example.com")

    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found

    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: "not-a-code" } },
          headers: { "Host" => @host, "Accept" => "application/json" }

    assert_response :unprocessable_content
    assert_predicate response.parsed_body.fetch("error"), :present?
  end

  test "successful OTP verification accepts the form scope used by the sign-in page" do
    user = clients(:one)
    test_email = user.client_emails.create!(address: "form_scope_test_#{SecureRandom.hex(4)}@example.com")

    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :client_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found
    assert_equal test_email.id, SignAppInEmailAuthenticationState.load(session)&.id

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    valid_pass_code = ROTP::HOTP.new(otp_private_key).at(otp_counter).to_s
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { client_email: { pass_code: valid_pass_code } },
          headers: { "Host" => @host }

    assert_response :found
    assert_redirected_to auth_app_sign_in_check_path(ri: "jp")
  end

  test "successful OTP verification sets host-only auth cookies" do
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "cookie_domain_in_#{SecureRandom.hex(4)}@example.com",
    )

    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 67_890
    valid_pass_code = ROTP::HOTP.new(otp_private_key).at(otp_counter).to_s
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: valid_pass_code } },
          headers: { "Host" => @host }

    auth_cookie_lines =
      response_set_cookie_lines.select do |line|
        line.start_with?("#{AuthenticationCookieName.access}=", "#{AuthenticationCookieName.refresh}=")
      end

    assert_equal 2, auth_cookie_lines.size
    auth_cookie_lines.each do |line|
      assert_includes line, "path=/"
      assert_match(/httponly/i, line)
      assert_no_match(/domain=/i, line)
    end
  end

  test "email sign-in redirects to MFA challenge when MFA is enabled" do
    user = clients(:one)
    user.update!(mfa_level_enabled: true)
    test_email = user.client_emails.create!(
      address: "mfa_email_login_#{SecureRandom.hex(4)}@example.com",
    )

    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 55_555
    valid_pass_code = ROTP::HOTP.new(otp_private_key).at(otp_counter).to_s
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: valid_pass_code } },
          headers: { "Host" => @host }

    assert_response :found
    assert_redirected_to auth_app_sign_in_challenge_path(ri: "jp")
  end

  def test_setup_cooldown_test_email
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "cooldown_test_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
      perform_enqueued_jobs do
        post(
          auth_app_sign_in_email_url(ri: "jp"),
          params: {
            :user_email => { address: test_email.address },
            "cf-turnstile-response" => "test_token",
          },
          headers: { "Host" => @host },
        )
      end
    end

    assert_response :found
    test_email.reload
    test_email
  end

  test "otp initial request sends email" do
    test_email = test_setup_cooldown_test_email

    assert_not_nil test_email.otp_last_sent_at
  end

  test "otp immediate resend is rejected with cooldown" do
    test_email = test_setup_cooldown_test_email
    initial_sent_at = test_email.otp_last_sent_at

    assert_no_difference -> { ActionMailer::Base.deliveries.count } do
      post auth_app_sign_in_email_url(ri: "jp"),
           params: {
             :user_email => { address: test_email.address },
             "cf-turnstile-response" => "test_token",
           },
           headers: { "Host" => @host }
    end

    assert_response :too_many_requests
    # The cooldown message must not depend on whether the address is registered.
    assert_includes @response.body, I18n.t("sign.app.authentication.email.create.cooldown")
    assert_equal initial_sent_at, test_email.reload.otp_last_sent_at
  end

  test "otp resend still rejected after 29 seconds" do
    test_email = test_setup_cooldown_test_email

    # Anchored to when the code was actually sent, not to now. `travel` moves
    # from the current moment, so on a slow run the setup alone can push the gap
    # past the cooldown and the case silently inverts into its opposite.
    travel_to test_email.otp_last_sent_at + 29.seconds do
      assert_no_difference -> { ActionMailer::Base.deliveries.count } do
        post auth_app_sign_in_email_url(ri: "jp"),
             params: {
               :user_email => { address: test_email.address },
               "cf-turnstile-response" => "test_token",
             },
             headers: { "Host" => @host }
      end

      assert_response :too_many_requests
    end
  end

  test "otp resend succeeds after cooldown expires" do
    test_email = test_setup_cooldown_test_email
    initial_sent_at = test_email.otp_last_sent_at

    travel 31.seconds do
      assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
        perform_enqueued_jobs do
          post auth_app_sign_in_email_url(ri: "jp"),
               params: {
                 :user_email => { address: test_email.address },
                 "cf-turnstile-response" => "test_token",
               },
               headers: { "Host" => @host }
        end
      end

      assert_response :found
      assert_operator test_email.reload.otp_last_sent_at, :>, initial_sent_at
    end
  end

  test "email sign in locks after five invalid OTP attempts" do
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "lockout_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    Email::MAX_OTP_ATTEMPTS.times do
      patch auth_app_sign_in_email_url(ri: "jp"),
            params: { user_email: { pass_code: "000000" } },
            headers: { "Host" => @host }
    end

    test_email.reload

    assert_response :unprocessable_content
    assert_predicate test_email, :locked?
    assert_operator test_email.lockout_expires_at, :>, Time.current
  end

  test "email sign in create does not send OTP during lockout" do
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "create_locked_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      locked_at: 5.minutes.from_now,
      otp_attempts_count: Email::MAX_OTP_ATTEMPTS,
    )

    travel CommonOtpPolicy::SEND_COOLDOWN + 1.second do
      assert_no_difference -> { ActionMailer::Base.deliveries.count } do
        post auth_app_sign_in_email_url(ri: "jp"),
             params: {
               :user_email => { address: test_email.address },
               "cf-turnstile-response" => "test_token",
             },
             headers: { "Host" => @host }
      end
    end

    assert_response :found
    assert_redirected_to %r{/sign/in/email/edit}
  end

  test "successful OTP verification records login audit event" do
    user = clients(:one)
    test_email = user.client_emails.create!(address: "audit_login_#{SecureRandom.hex(4)}@example.com")

    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_equal test_email.id, SignAppInEmailAuthenticationState.load(session)&.id

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    hotp = ROTP::HOTP.new(otp_private_key)
    valid_pass_code = hotp.at(otp_counter).to_s
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    assert_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::LOGGED_IN).count }, 1 do
      patch auth_app_sign_in_email_url(ri: "jp"),
            params: { user_email: { pass_code: valid_pass_code } },
            headers: { "Host" => @host }
    end

    audit = ClientChronicle.order(created_at: :desc).first

    assert_equal ClientChronicleEvent::LOGGED_IN, audit.event_id
    assert_equal user, audit.user
  end

  test "invalid OTP code returns error message" do
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "invalid_otp_test_#{SecureRandom.hex(4)}@example.com",
    )

    # Start authentication
    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_equal test_email.id, SignAppInEmailAuthenticationState.load(session)&.id

    # Set up valid OTP but provide wrong code
    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    # Try with invalid code
    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: "999999" } },
          headers: { "Host" => @host }

    # Should render edit page with error
    assert_response :unprocessable_content
    assert_includes @response.body, I18n.t("sign.app.authentication.email.update.invalid_code", locale: :ja)
  end

  test "blank OTP code returns error message" do
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "blank_otp_test_#{SecureRandom.hex(4)}@example.com",
    )

    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_equal test_email.id, SignAppInEmailAuthenticationState.load(session)&.id

    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: "" } },
          headers: { "Host" => @host }

    assert_response :unprocessable_content
    assert_includes @response.body, I18n.t("sign.app.authentication.email.update.invalid_code", locale: :ja)
  end

  test "invalid OTP attempt records login failed audit event" do
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "audit_login_failed_#{SecureRandom.hex(4)}@example.com",
    )

    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_equal test_email.id, SignAppInEmailAuthenticationState.load(session)&.id

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 56_789
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    assert_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::LOGIN_FAILED).count }, 1 do
      patch auth_app_sign_in_email_url(ri: "jp"),
            params: { user_email: { pass_code: "000000" } },
            headers: { "Host" => @host }
    end

    audit = ClientChronicle.order(created_at: :desc).first

    assert_equal ClientChronicleEvent::LOGIN_FAILED, audit.event_id
    assert_equal user, audit.user
  end

  test "email post starts sign-in challenge when no browser session is present" do
    user = clients(:one)
    post auth_app_sign_in_email_url(ri: "jp"),
         params: { user_email: { address: "some@example.com" } },
         headers: { "Host" => @host, "X-TEST-CURRENT-USER" => user.id }

    assert_response :found
    assert_redirected_to edit_auth_app_sign_in_email_path(ri: "jp")
  end

  test "redirects to encoded URL after successful login when pt parameter is provided" do
    # Create a test user and email
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "redirect_login_test_#{SecureRandom.hex(4)}@example.com",
    )

    redirect_url = auth_app_settings_path(ri: "jp")
    pt = redirect_url

    # Start authentication with pt parameter
    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
           :pt => pt,
         },
         headers: { "Host" => @host }

    assert_response :found
    assert_not_includes response.location, "pt="
    assert_equal test_email.id, SignAppInEmailAuthenticationState.load(session)&.id
    assert_nil session[:user_email_authentication_rt]

    # Generate valid OTP code
    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    hotp = ROTP::HOTP.new(otp_private_key)
    valid_pass_code = hotp.at(otp_counter).to_s

    # Store OTP
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    # Verify OTP with pt parameter
    patch auth_app_sign_in_email_url(ri: "jp"),
          params: {
            user_email: { pass_code: valid_pass_code },
            pt: pt,
          },
          headers: { "Host" => @host }

    assert_response :found
    assert_redirected_to auth_app_sign_in_check_path(ri: "jp")

    cycle = ClientSignInFlow.where(principal_id: user.id).recent_first.first

    assert_equal "CHECKPOINT_PENDING", cycle.state
    assert_nil cycle.return_to
    assert_equal "CHECKPOINT_PENDING", cycle.reload.state
    assert_nil cycle.return_to
  end

  test "rejects external pt parameter after successful login" do
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "redirect_external_test_#{SecureRandom.hex(4)}@example.com",
    )

    pt = "https://example.com/evil"

    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
           :pt => pt,
         },
         headers: { "Host" => @host }

    assert_response :found
    assert_no_match(/pt=/, response.location)

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    hotp = ROTP::HOTP.new(otp_private_key)
    valid_pass_code = hotp.at(otp_counter).to_s

    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    patch auth_app_sign_in_email_url(ri: "jp"),
          params: {
            user_email: { pass_code: valid_pass_code },
            pt: pt,
          },
          headers: { "Host" => @host }

    assert_response :found
    assert_redirected_to auth_app_sign_in_check_path(ri: "jp")
  end

  test "resets session ID after successful email login" do
    # Create email with user association
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "session_reset_login_#{SecureRandom.hex(4)}@example.com",
    )

    # Start authentication
    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found
    assert_predicate SignAppInEmailAuthenticationState.load(session)&.id, :present?

    # Generate valid OTP code
    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    hotp = ROTP::HOTP.new(otp_private_key)
    valid_pass_code = hotp.at(otp_counter).to_s

    # Store OTP
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    # Ensure we have a session
    old_session_id = session.id

    # Verify OTP to log in
    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: valid_pass_code } },
          headers: { "Host" => @host }

    assert_response :found
    assert_not_nil session.id
    assert_not_equal old_session_id, session.id
  end

  test "email login with session limit exceeded redirects to session management" do
    user = clients(:one)
    ClientToken.where(user_id: user.id).delete_all

    # Create 2 active sessions to hit the limit
    2.times do
      create_rotated_active_user_session(user, rotations: 3)
    end

    test_email = user.client_emails.create!(
      address: "session_limit_email_#{SecureRandom.hex(4)}@example.com",
    )

    # Start authentication
    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    # Generate valid OTP code
    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    hotp = ROTP::HOTP.new(otp_private_key)
    valid_pass_code = hotp.at(otp_counter).to_s
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    # Verify OTP - should redirect to session management, not "/"
    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: valid_pass_code } },
          headers: { "Host" => @host }

    assert_response :found
    assert_redirected_to auth_app_sign_in_session_path(ri: "jp")

    # The current session-limit gate keeps the pending login in session state.
    restricted = ClientToken.where(user_id: user.id, user_token_status_id: ClientTokenStatus::RESTRICTED)

    assert_equal 0, restricted.count

    # Session limit gate should be issued
    assert_predicate session[SessionLimitGate::GATE_SESSION_KEY], :present?
  end

  test "email login hard rejects when a restricted session already exists" do
    user = clients(:one)
    ClientToken.where(user_id: user.id).delete_all

    2.times do
      create_rotated_active_user_session(user, rotations: 3)
    end

    test_email = user.client_emails.create!(
      address: "session_limit_hard_reject_#{SecureRandom.hex(4)}@example.com",
    )

    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    hotp = ROTP::HOTP.new(otp_private_key)
    valid_pass_code = hotp.at(otp_counter).to_s
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    ClientToken.create!(user: user, user_token_status_id: ClientTokenStatus::RESTRICTED)

    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: valid_pass_code } },
          headers: { "Host" => @host }

    assert_response :forbidden
    assert_includes response.body, "セッション数の上限に達しました"
    assert_equal 1, ClientToken.where(user_id: user.id, user_token_status_id: ClientTokenStatus::RESTRICTED).count
  end

  test "email login (JSON) with session limit exceeded returns session_restricted" do
    user = clients(:one)
    ClientToken.where(user_id: user.id).delete_all

    2.times do
      create_rotated_active_user_session(user, rotations: 3)
    end

    test_email = user.client_emails.create!(
      address: "session_limit_json_#{SecureRandom.hex(4)}@example.com",
    )

    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    hotp = ROTP::HOTP.new(otp_private_key)
    valid_pass_code = hotp.at(otp_counter).to_s
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: valid_pass_code } },
          headers: { "Host" => @host, "Accept" => "application/json" },
          as: :json

    assert_response :ok
    json = response.parsed_body

    assert_equal "session_restricted", json["status"]
    assert_equal auth_app_sign_in_session_path(ri: "jp"), json["redirect_url"]
  end

  test "cooldown applies identically for non-existing emails (anti-enumeration)" do
    non_existing = "does_not_exist_#{SecureRandom.hex(4)}@example.com"

    # First attempt -- redirect (same as existing email)
    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: non_existing },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found

    # Second attempt immediately -- 429 (same as existing email)
    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: non_existing },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :too_many_requests
    assert_includes @response.body, I18n.t("sign.app.authentication.email.create.cooldown")

    # After cooldown -- allowed again
    travel CommonOtpPolicy::SEND_COOLDOWN + 1.second do
      post auth_app_sign_in_email_url(ri: "jp"),
           params: {
             :user_email => { address: non_existing },
             "cf-turnstile-response" => "test_token",
           },
           headers: { "Host" => @host }

      assert_response :found
    end
  end

  test "cooldown returns the non-disclosing cooldown message after immediate re-login" do
    user = clients(:one)
    email = user.client_emails.create!(
      address: "cooldown_login_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           user_email: { address: email.address },
           "cf-turnstile-response": "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found

    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           user_email: { address: email.address },
           "cf-turnstile-response": "test_token",
         },
         headers: { "Host" => @host }

    assert_response :too_many_requests
    # A registered address must get the same message an unregistered one gets.
    # See test/controllers/auth/app/in/emails_controller_enumeration_test.rb.
    assert_includes response.body, I18n.t("sign.app.authentication.email.create.cooldown")
  end

  test "cooldown does not block different email addresses" do
    first_email = "first_signin_#{SecureRandom.hex(4)}@example.com"
    second_email = "second_signin_#{SecureRandom.hex(4)}@example.com"

    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: first_email },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found

    # Different email should not be blocked
    post auth_app_sign_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: second_email },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found
  end

  test "sign-in cooldown i18n keys exist in both locales" do
    assert_not_nil I18n.t("sign.app.authentication.email.create.cooldown", locale: :ja, default: nil)
    assert_not_nil I18n.t("sign.app.authentication.email.create.cooldown", locale: :en, default: nil)
  end

  private

  def create_rotated_active_user_session(user, rotations:)
    token = ClientToken.create!(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
    refresh = token.rotate_refresh_token!

    rotations.times do
      refresh = SignRefreshTokenIssuer.call(refresh_token: refresh)[:refresh_token]
    end
  end
  private
end

# DAMP auth header helpers for this test class.
class Auth::App::Sign::In::EmailsControllerTest
  private
end

# DAMP local helper copy for former shared test support.
class Auth::App::Sign::In::EmailsControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil, resource_type: nil,
                           dpop_jkt: nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || "unknown"
    resource_type ||=
      case resource
      when Client then "client"
      when Operator then "operator"
      when Visitor then "visitor"
      end
    AuthenticationToken.encode(
      resource,
      host: host_value,
      session_id: session_id,
      session_public_id: session_public_id,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: jwt_issuer_id_for_test_host(host_value, resource_type),
    )
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "SIGN")
    surface =
      if service == "SIGN"
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
      address_digest: IdentifierBlindIndex.bidx_for_email(address),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
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
          address_digest: IdentifierBlindIndex.bidx_for_email(address),
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          otp_private_key: SecureRandom.base64(24),
          otp_counter: "",
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
class Auth::App::Sign::In::EmailsControllerTest
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

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)
    return base unless user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"

    ensure_user_token_reference_records!
    token = session_public_id.present? ? ClientToken.find_by(public_id: session_public_id) : nil
    token ||= ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
    token ||= ClientToken.create!(
      user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
      }",
      )
    else
      base
    end
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)
    return base unless staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"

    ensure_staff_token_reference_records!
    token = session_public_id.present? ? OperatorToken.find_by(public_id: session_public_id) : nil
    token ||= OperatorToken.where(staff_id: staff.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= OperatorToken.create!(
      staff_id: staff.id, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }",
      )
    else
      base
    end
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)
    return base unless visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"

    ensure_visitor_token_reference_records!
    token = session_public_id.present? ? VisitorToken.find_by(public_id: session_public_id) : nil
    token ||= VisitorToken.where(visitor_id: visitor.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= VisitorToken.create!(
      visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor")
      }",
      )
    else
      base
    end
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
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
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
    %w(SIGN_APP SIGN_ORG SIGN_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
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
