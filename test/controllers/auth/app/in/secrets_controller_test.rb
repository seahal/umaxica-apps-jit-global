# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::Sign::In::SecretsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_secret_credential_kinds,
           :client_secret_credential_statuses, :client_email_statuses,
           :client_telephone_statuses

  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @user = clients(:one)
    @raw_email = "secret_credential_login_#{SecureRandom.hex(4)}@example.com".freeze
    @email = @user.client_emails.create!(address: @raw_email, user_email_status_id: ClientEmailStatus::VERIFIED)
    @telephone = @user.client_telephones.create!(number: "+819012345678")
    ClientToken.where(user_id: @user.id).delete_all
    @original_login_cooldown = login_cooldown
    self.login_cooldown = 0.seconds
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    self.login_cooldown = @original_login_cooldown
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "should get new" do
    get new_auth_app_sign_in_secret_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_equal "auth/app/sign/in/secrets/new", inertia_component
    assert_equal "jp", inertia_props.fetch("form").fetch("ri")
    assert_equal auth_app_sign_in_path(ri: "jp"), inertia_props.fetch("back_link").fetch("href")
  end

  test "should return unprocessable_content with invalid params" do
    post auth_app_sign_in_secret_url(ri: "jp"),
         params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } },
         headers: default_headers

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("form_errors"),
                    I18n.t("sign.app.authentication.secret_credential.create.invalid")
  end

  test "identifier without @ or + is rejected" do
    _secret_credential, raw_secret_credential = issue_secret_credential!

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: "plaintext", secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("form_errors"),
                    I18n.t("sign.app.authentication.secret_credential.create.invalid")
  end

  test "returns 403 when user is at session hard_reject limit" do
    _secret_credential, raw_secret_credential = issue_secret_credential!(
      kind: ClientSecretCredentialKind::PERMANENT,
      uses: 10,
    )

    # Create 2 active + 1 restricted to hit the hard limit
    ClientToken.where(user_id: @user.id).delete_all
    Prosopite.pause do
      2.times do
        create_rotated_active_user_session(@user, rotations: 3)
      end
    end
    restricted = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted.rotate_refresh_token!(discarded_at: 15.minutes.from_now)

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :forbidden
    assert_includes response.body, I18n.t("session_limit.login_limit_exceeded")
  end

  test "redirects to session management when logical session limit is reached despite rotated rows" do
    _secret_credential, raw_secret_credential = issue_secret_credential!(
      kind: ClientSecretCredentialKind::PERMANENT,
      uses: 10,
    )

    ClientToken.where(user_id: @user.id).delete_all
    Prosopite.pause do
      2.times do
        create_rotated_active_user_session(@user, rotations: 4)
      end
    end

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :found
    assert_redirected_to auth_app_sign_in_session_path(ri: "jp")
    assert_nil flash[:notice]
    assert_equal 0, ClientToken.where(user_id: @user.id, user_token_status_id: ClientTokenStatus::RESTRICTED).count
  end

  test "turnstile failure returns unified authentication error" do
    TurnstileVerifierStub.challenge_response = { "success" => false }
    _secret_credential, raw_secret_credential = issue_secret_credential!

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("form_errors"),
                    I18n.t("sign.app.authentication.secret_credential.create.invalid")
  end

  test "server-side Turnstile verifier failure rejects secret credential login" do
    calls = []
    verifier =
      lambda do |token:, remote_ip:, mode:, **|
        calls << { token: token, remote_ip: remote_ip, mode: mode }
        { "success" => false }
      end

    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.stub(:verify, verifier) do
      post(
        auth_app_sign_in_secret_url(ri: "jp"),
        params: login_params(identifier: @raw_email, secret_credential_value: "not-checked"),
        headers: default_headers,
      )
    end

    assert_response :unprocessable_content
    assert_equal [{ token: "test_token", remote_ip: "127.0.0.1", mode: :visible }], calls
    assert_includes inertia_props.fetch("form_errors"),
                    I18n.t("sign.app.authentication.secret_credential.create.invalid")
  ensure
    TurnstileVerifierStub.challenge_enabled = true
  end

  test "email and matching permanent secret_credential logs in successfully" do
    _secret_credential, raw_secret_credential = issue_secret_credential!(
      kind: ClientSecretCredentialKind::PERMANENT,
      uses: 10,
    )

    get new_auth_app_sign_in_secret_url(ri: "jp"), headers: default_headers

    assert_response :success
    old_session_id = session.id

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email.upcase, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :found
    assert_redirected_to auth_app_sign_in_check_path(ri: "jp")
    assert_not_equal old_session_id, session.id
  end

  test "email and matching permanent secret_credential falls back to jp when ri is missing" do
    _secret_credential, raw_secret_credential = issue_secret_credential!(
      kind: ClientSecretCredentialKind::PERMANENT,
      uses: 10,
    )

    post auth_app_sign_in_secret_url,
         params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :found
    assert_redirected_to auth_app_sign_in_check_path(ri: "jp")
  end

  test "email and matching permanent secret_credential canonicalizes invalid ri" do
    _secret_credential, raw_secret_credential = issue_secret_credential!(
      kind: ClientSecretCredentialKind::PERMANENT,
      uses: 10,
    )

    post auth_app_sign_in_secret_url(ri: "https://evil.example"),
         params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :see_other
    assert_redirected_to auth_app_sign_in_secret_url(ri: "jp")
    assert_no_match(/evil\.example/, response.location)
  end

  test "telephone and matching permanent secret_credential logs in successfully" do
    _secret_credential, raw_secret_credential = issue_secret_credential!(
      kind: ClientSecretCredentialKind::PERMANENT,
      uses: 10,
    )

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: "+819012345678", secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :found
    assert_redirected_to auth_app_sign_in_check_path(ri: "jp")
  end

  test "secret_credential sign-in redirects to MFA challenge for weak method when MFA is enabled" do
    @user.update!(mfa_level_enabled: true)
    _secret_credential, raw_secret_credential = issue_secret_credential!(
      kind: ClientSecretCredentialKind::PERMANENT,
      uses: 10,
    )

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :found
    assert_redirected_to auth_app_sign_in_challenge_path(ri: "jp")
  end

  test "the second-factor secret credential submission is rejected when it does not match" do
    @user.update!(mfa_level_enabled: true)
    _secret_credential, raw_secret_credential = issue_secret_credential!(
      kind: ClientSecretCredentialKind::PERMANENT,
      uses: 10,
    )

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_redirected_to auth_app_sign_in_challenge_path(ri: "jp")

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: {
           :mfa_secret_credential_form => { secret_credential_value: "wrong-secret_credential" },
           "cf-turnstile-response" => "test_token",
         },
         headers: default_headers

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("form_errors"),
                    I18n.t("sign.app.authentication.secret_credential.create.invalid")
  end

  test "a blank second-factor secret credential is rejected before any verification runs" do
    @user.update!(mfa_level_enabled: true)
    _secret_credential, raw_secret_credential = issue_secret_credential!(
      kind: ClientSecretCredentialKind::PERMANENT,
      uses: 10,
    )

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_redirected_to auth_app_sign_in_challenge_path(ri: "jp")

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: {
           :mfa_secret_credential_form => { secret_credential_value: "" },
           "cf-turnstile-response" => "test_token",
         },
         headers: default_headers

    assert_response :unprocessable_content
  end

  test "an unexpected failure while verifying the second factor is reported without leaking the cause" do
    @user.update!(mfa_level_enabled: true)
    _secret_credential, raw_secret_credential = issue_secret_credential!(
      kind: ClientSecretCredentialKind::PERMANENT,
      uses: 10,
    )

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_redirected_to auth_app_sign_in_challenge_path(ri: "jp")

    exploding = ->(**) { raise IOError, "verifier unavailable" }

    ClientSecretCredential.stub(:allowed_for_secret_credential_sign_in, exploding) do
      post auth_app_sign_in_secret_url(ri: "jp"),
           params: {
             :mfa_secret_credential_form => { secret_credential_value: raw_secret_credential },
             "cf-turnstile-response" => "test_token",
           },
           headers: default_headers
    end

    assert_response :unprocessable_content
    assert_not_includes response.body, "verifier unavailable"
  end

  test "mismatched secret_credential fails with unified message" do
    _secret_credential, _raw_secret_credential = issue_secret_credential!

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: "wrong-secret_credential"),
         headers: default_headers

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("form_errors"),
                    I18n.t("sign.app.authentication.secret_credential.create.invalid")
  end

  test "unknown user fails with unified message" do
    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(
           identifier: "missing-#{SecureRandom.hex(4)}@example.com",
           secret_credential_value: "nope",
         ),
         headers: default_headers

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("form_errors"),
                    I18n.t("sign.app.authentication.secret_credential.create.invalid")
  end

  test "known user with no secret_credential fails with unified message" do
    @user.client_secret_credentials.delete_all

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: "nope"),
         headers: default_headers

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("form_errors"),
                    I18n.t("sign.app.authentication.secret_credential.create.invalid")
  end

  test "legacy secret_credential still uses the legacy verifier" do
    _secret_credential, raw_secret_credential = issue_secret_credential!(
      kind: ClientSecretCredentialKind::PERMANENT,
      uses: 10,
    )

    SignSecretVerify.stub(:call, ->(*) { flunk("new-axis verifier must not be used for legacy rows") }) do
      post auth_app_sign_in_secret_url(ri: "jp"),
           params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
           headers: default_headers
    end

    assert_response :found
    assert_redirected_to auth_app_sign_in_check_path(ri: "jp")
  end

  test "new-axis recovery secret uses the new verifier" do
    result = issue_new_axis_secret_credential!

    legacy_method = ClientSecretCredential.instance_method(:verify_for_secret_credential_sign_in!)

    ClientSecretCredential.define_method(:verify_for_secret_credential_sign_in!) do |*|
      raise StandardError, "legacy verifier must not be used for new-axis rows"
    end

    begin
      SignSecretVerify.stub(
        :call,
        lambda do |*args, **kwargs|
          secret_credential = kwargs[:secret_credential] || args.first&.fetch(:secret_credential)
          raw_secret_credential = kwargs[:raw_secret_credential] || args.first&.fetch(:raw_secret_credential)

          assert_predicate secret_credential, :new_axis_secret_credential?
          assert_equal result.raw_secret_credential, raw_secret_credential

          SignSecretVerify::Result.new(
            secret_credential: secret_credential,
            reason: :success,
            details: { secret_credential_id: secret_credential.id },
          )
        end,
      ) do
        post(
          auth_app_sign_in_secret_url(ri: "jp"),
          params: login_params(identifier: @raw_email, secret_credential_value: result.raw_secret_credential),
          headers: default_headers,
        )
      end
    ensure
      ClientSecretCredential.define_method(:verify_for_secret_credential_sign_in!, legacy_method)
    end

    assert_response :found
    assert_redirected_to auth_app_sign_in_check_path(ri: "jp")
  end

  test "reserved user cannot sign in with secret_credential" do
    reserved_user = clients(:reserved_user)
    email = reserved_user.client_emails.create!(
      address: "reserved_secret_credential_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    secret_credential, raw_secret_credential = ClientSecretCredential.issue!(
      name: "Reserved secret_credential",
      user_id: reserved_user.id,
      user_secret_kind_id: ClientSecretCredentialKind::PERMANENT,
      uses: 10,
      status: :active,
    )

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: email.address, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("form_errors"),
                    I18n.t("sign.app.authentication.secret_credential.create.invalid")
    assert_equal ClientSecretCredentialStatus::ACTIVE, secret_credential.reload.user_secret_status_id
  end

  test "secret_credential login returns same response for secret_credential mismatch and missing verified pii" do
    _secret_credential, _raw_secret_credential = issue_secret_credential!(
      kind: ClientSecretCredentialKind::PERMANENT,
      uses: 10,
    )

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: "wrong-secret_credential"),
         headers: default_headers

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("form_errors"),
                    I18n.t("sign.app.authentication.secret_credential.create.invalid")

    user_without_verified_pii = Client.create!(status_id: ClientStatus::NOTHING)
    email_for_secret_credential_issue = user_without_verified_pii.client_emails.create!(
      address: "secret_credential_verified_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    _pii_secret_credential, pii_raw_secret_credential = ClientSecretCredential.issue!(
      name: "PII missing secret_credential",
      user_id: user_without_verified_pii.id,
      user_secret_kind_id: ClientSecretCredentialKind::PERMANENT,
      uses: 10,
      status: :active,
    )
    email_for_secret_credential_issue.update!(user_email_status_id: ClientEmailStatus::UNVERIFIED)
    unverified_email = user_without_verified_pii.client_emails.create!(
      address: "secret_credential_unverified_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
    )

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: unverified_email.address, secret_credential_value: pii_raw_secret_credential),
         headers: default_headers

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("form_errors"),
                    I18n.t("sign.app.authentication.secret_credential.create.invalid")
  end

  test "one-time secret_credential decrements uses and cannot be reused once exhausted" do
    one_time_secret_credential, raw_secret_credential = issue_secret_credential!(
      kind: ClientSecretCredentialKind::ONE_TIME, uses: 1,
    )

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :found
    assert_redirected_to auth_app_sign_in_check_path(ri: "jp")
    assert_equal 0, one_time_secret_credential.reload.uses_remaining
    assert_equal ClientSecretCredentialStatus::USED, one_time_secret_credential.user_secret_status_id

    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("form_errors"),
                    I18n.t("sign.app.authentication.secret_credential.create.invalid")
  end

  test "expired secret_credential fails authentication" do
    _secret_credential, raw_secret_credential = issue_secret_credential!(discarded_at: 1.minute.ago)

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("form_errors"),
                    I18n.t("sign.app.authentication.secret_credential.create.invalid")
  end

  test "one-time secret_credential with uses_remaining 0 fails authentication" do
    secret_credential, raw_secret_credential = issue_secret_credential!(
      kind: ClientSecretCredentialKind::ONE_TIME,
      uses: 1,
    )
    secret_credential.update!(uses_remaining: 0)

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("form_errors"),
                    I18n.t("sign.app.authentication.secret_credential.create.invalid")
  end

  test "secret_credential with disallowed status fails authentication" do
    _secret_credential, raw_secret_credential = issue_secret_credential!(status: :revoked)

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("form_errors"),
                    I18n.t("sign.app.authentication.secret_credential.create.invalid")
  end

  test "secret_credential with disallowed kind fails authentication" do
    _secret_credential, raw_secret_credential = issue_secret_credential!(
      kind: ClientSecretCredentialKind::TOTP,
      uses: 10,
    )

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("form_errors"),
                    I18n.t("sign.app.authentication.secret_credential.create.invalid")
  end

  test "secret_credential login succeeds without extra confirmation parameter" do
    _secret_credential, raw_secret_credential = issue_secret_credential!

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :found
    assert_redirected_to auth_app_sign_in_check_path(ri: "jp")
    assert_not_nil session.id
  end

  test "guest request does not query clients with null mfa_user_id" do
    queries =
      capture_sql_queries do
        get(new_auth_app_sign_in_secret_url(ri: "jp"), headers: default_headers)

        assert_response :success
      end

    assert_response :success
    assert_not queries.any? { |sql| sql.match?(/FROM "clients".*"clients"."id" IS NULL/i) },
               "expected no clients.id IS NULL query, got: #{queries.grep(/clients/i).join("\n")}"
  end

  private

  def create_rotated_active_user_session(user, rotations:)
    token = ClientToken.create!(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
    refresh = token.rotate_refresh_token!

    rotations.times do
      refresh = SignRefreshTokenIssuer.call(refresh_token: refresh)[:refresh_token]
    end
  end

  def issue_secret_credential!(kind: ClientSecretCredentialKind::PERMANENT, uses: 1, discarded_at: nil, status: :active)
    ClientSecretCredential.issue!(
      name: "Secret-#{SecureRandom.hex(4)}",
      user_id: @user.id,
      user_secret_kind_id: kind,
      uses: uses,
      discarded_at: discarded_at,
      status: status,
    )
  end

  def issue_new_axis_secret_credential!
    SignSecretIssue.call(
      credential_collection: @user.client_secret_credentials,
      secret_credential_class: ClientSecretCredential,
      name: "Recovery",
      secret_kind: "recovery",
      usage_policy: "single_use",
      legacy_attributes: {
        user_secret_kind_id: ClientSecretCredentialKind::RECOVERY,
        user_secret_status_id: ClientSecretCredentialStatus::ACTIVE,
      },
      scope: "recovery",
      max_uses: 1,
      max_failures: 5,
    )
  end

  def login_params(identifier:, secret_credential_value:)
    {
      secret_credential_login_form: {
        identifier: identifier,
        secret_credential_value: secret_credential_value,
      },
      "cf-turnstile-response": "test_token",
    }
  end

  def default_headers
    { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost") }
  end

  def capture_sql_queries
    queries = []
    callback =
      lambda do |_name, _started, _finished, _id, payload|
        sql = payload[:sql].to_s
        next if sql.blank?
        next if payload[:name].to_s == "SCHEMA"
        next if payload[:cached]

        queries << sql
      end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      yield
    end
    queries
  end

  public

  test "secret_credential login with session limit exceeded redirects to session management" do
    ClientToken.where(user_id: @user.id).delete_all

    # Create 2 active sessions to hit the limit
    Prosopite.pause do
      2.times do
        token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
        token.rotate_refresh_token!
      end
    end

    _secret_credential, raw_secret_credential = issue_secret_credential!(
      kind: ClientSecretCredentialKind::PERMANENT,
      uses: 10,
    )

    post auth_app_sign_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_credential_value: raw_secret_credential),
         headers: default_headers

    assert_response :found
    assert_redirected_to auth_app_sign_in_session_path(ri: "jp")
    assert_equal 0, ClientToken.where(user_id: @user.id, user_token_status_id: ClientTokenStatus::RESTRICTED).count
  end

  test "direct controller branches for mfa and standard secret_credential flows" do
    controller = Auth::App::Sign::In::SecretsController.new
    session_hash = {}
    params_hash = ActionController::Parameters.new(
      "ri" => "jp",
      "cf-turnstile-response" => "test_token",
    )
    failures = []
    redirects = []
    renders = []
    target_user = @user

    controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => host)
    controller.response = ActionDispatch::TestResponse.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { params_hash }
    controller.define_singleton_method(:render_failed_login) { |**kwargs| failures << kwargs }
    controller.define_singleton_method(:render_session_limit_hard_reject) { |**kwargs|
      failures << kwargs.merge(reason: :hard_reject)
    }
    # `new` renders the Inertia page; this bare controller is exercised for its branch logic and
    # is reused across branches, so the single-render rule is satisfied by recording the render.
    controller.define_singleton_method(:render_secret_new) { |status: :ok| renders << status }
    controller.define_singleton_method(:redirect_to) { |path, **kwargs| redirects << [path, kwargs] }
    controller.define_singleton_method(:redirect_to_pt_or_default!) { |pt, default_path:|
      redirects << [pt || default_path, {}]
    }
    controller.define_singleton_method(:auth_app_settings_path) { |ri: nil| "/settings?ri=#{ri}" }
    controller.define_singleton_method(:auth_app_root_path) { |ri: nil, pt: nil|
      "/?ri=#{ri}#{pt ? "&pt=#{pt}" : ""}"
    }
    controller.define_singleton_method(:auth_app_sign_in_session_path) { "/sign/in/session" }
    controller.define_singleton_method(:auth_app_sign_in_check_path) { |pt: nil, ri: nil|
      "/sign/in/check?pt=#{pt}&ri=#{ri}"
    }
    controller.define_singleton_method(:t) { |key| key }

    controller.new

    assert_instance_of Auth::App::Sign::In::SecretsController::SecretLoginForm,
                       controller.instance_variable_get(:@secret_credential_form)

    # set_pending_mfa! always writes both the legacy alias and the TTL-bearing
    # :pending_mfa entry; the controller now requires the TTL to still be valid.
    session_hash[Auth::App::Sign::In::SecretsController::MFA_USER_SESSION_KEY] = @user.id
    session_hash[:pending_mfa] = {
      "user_id" => @user.id,
      "issued_at" => Time.current.to_i,
      "expires_at" => 10.minutes.from_now.to_i,
      "attempts" => 0,
    }
    controller.remove_instance_variable(:@mfa_user)
    controller.define_singleton_method(:active_secret_credential_hints_for) { |_| ["hint"] }
    controller.new

    assert_instance_of Auth::App::Sign::In::SecretsController::MfaSecretForm,
                       controller.instance_variable_get(:@secret_credential_form)
    assert_equal ["hint"], controller.instance_variable_get(:@secret_credential_hints)

    # An expired pending-MFA window must drop back to the primary form rather than
    # letting the second factor be completed later inside the 14-day session cookie.
    session_hash[:pending_mfa] = session_hash[:pending_mfa].merge(
      "issued_at" => 20.minutes.ago.to_i,
      "expires_at" => 10.minutes.ago.to_i,
    )
    controller.remove_instance_variable(:@mfa_user)
    controller.new

    assert_instance_of Auth::App::Sign::In::SecretsController::SecretLoginForm,
                       controller.instance_variable_get(:@secret_credential_form)
    assert_nil session_hash[Auth::App::Sign::In::SecretsController::MFA_USER_SESSION_KEY],
               "The expired ceremony must be cleared, not left half-present in the session."

    # Restore a valid window for the remaining assertions in this test.
    session_hash[Auth::App::Sign::In::SecretsController::MFA_USER_SESSION_KEY] = @user.id
    session_hash[:pending_mfa] = {
      "user_id" => @user.id,
      "issued_at" => Time.current.to_i,
      "expires_at" => 10.minutes.from_now.to_i,
      "attempts" => 0,
    }
    controller.remove_instance_variable(:@mfa_user)
    controller.new

    params_hash[:mfa_secret_credential_form] = ActionController::Parameters.new(secret_credential_value: "")
    controller.handle_mfa_login

    assert_equal :form_invalid, failures.last[:reason]

    params_hash[:mfa_secret_credential_form] =
      ActionController::Parameters.new(secret_credential_value: "secret_credential")
    controller.define_singleton_method(:cloudflare_turnstile_validation) { { "success" => false } }
    controller.handle_mfa_login

    assert_equal :turnstile_failed, failures.last[:reason]

    secret_credential = Struct.new(:id).new(99)
    controller.define_singleton_method(:cloudflare_turnstile_validation) { { "success" => true } }
    controller.define_singleton_method(:verify_secret_credential_for_sign_in) do |user:, raw_secret_credential:|
      Auth::App::Sign::In::SecretsController::SecretVerificationResult.new(
        secret_credential: secret_credential, reason: :success,
        details: { user_id: user.id, raw: raw_secret_credential },
      )
    end
    controller.define_singleton_method(:handle_successful_mfa) { |u, verified_secret_credential|
      redirects << [u.id, secret_credential_id: verified_secret_credential.id]
    }
    controller.handle_mfa_login

    assert_equal [@user.id, { secret_credential_id: 99 }], redirects.last

    session_hash.delete(Auth::App::Sign::In::SecretsController::MFA_USER_SESSION_KEY)
    params_hash.delete(:mfa_secret_credential_form)
    params_hash[:secret_credential_login_form] =
      ActionController::Parameters.new(identifier: "", secret_credential_value: "")
    controller.handle_standard_login

    assert_equal :form_invalid, failures.last[:reason]

    params_hash[:secret_credential_login_form] = ActionController::Parameters.new(
      identifier: @raw_email,
      secret_credential_value: "secret_credential",
    )
    controller.define_singleton_method(:cloudflare_turnstile_validation) { { "success" => false } }
    controller.handle_standard_login

    assert_equal :turnstile_failed, failures.last[:reason]

    controller.define_singleton_method(:cloudflare_turnstile_validation) { { "success" => true } }
    controller.define_singleton_method(:find_user_by_identifier) { |_| target_user }
    controller.define_singleton_method(:session_limit_hard_reject_for?) { |_| true }
    controller.handle_standard_login

    assert_equal :hard_reject, failures.last[:reason]

    controller.define_singleton_method(:session_limit_hard_reject_for?) { |_| false }
    controller.define_singleton_method(:verify_secret_credential_for_sign_in) do |user:, raw_secret_credential:|
      Auth::App::Sign::In::SecretsController::SecretVerificationResult.new(
        secret_credential: nil, reason: :secret_credential_mismatch,
        details: { user_id: user.id, raw: raw_secret_credential },
      )
    end
    controller.handle_standard_login

    assert_equal :secret_credential_mismatch, failures.last[:reason]
    # Every `new` above answered by rendering the sign-in page with a 200.
    assert_equal %i(ok ok ok ok), renders
  end

  test "direct controller success handlers cover mfa and standard redirects" do
    controller = Auth::App::Sign::In::SecretsController.new
    session_hash = {}
    params_hash = ActionController::Parameters.new(
      "ri" => "jp",
      "pt" => "encoded-pt",
      "cf-turnstile-response" => "test_token",
    )
    redirects = []
    failures = []

    controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => host)
    controller.response = ActionDispatch::TestResponse.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { params_hash }
    controller.define_singleton_method(:redirect_to) { |path, **kwargs| redirects << [path, kwargs] }
    controller.define_singleton_method(:redirect_to_jump_url) { |url, **kwargs| redirects << [url, kwargs] }
    controller.define_singleton_method(:redirect_to_pt_or_default!) { |pt, default_path:|
      redirects << [pt || default_path, {}]
    }
    controller.define_singleton_method(:render_failed_login) { |**kwargs| failures << kwargs }
    controller.define_singleton_method(:render_session_limit_hard_reject) { |**kwargs|
      failures << kwargs.merge(reason: :hard_reject)
    }
    controller.define_singleton_method(:auth_app_settings_path) { |ri: nil| "/settings?ri=#{ri}" }
    controller.define_singleton_method(:auth_app_sign_in_session_path) { "/sign/in/session" }
    controller.define_singleton_method(:auth_app_sign_in_check_path) { |pt: nil, ri: nil|
      "/sign/in/check?pt=#{pt}&ri=#{ri}"
    }
    controller.define_singleton_method(:t) { |key| key }
    controller.define_singleton_method(:clear_mfa_session!) { session_hash[Auth::App::Sign::In::SecretsController::MFA_USER_SESSION_KEY] = nil }

    secret_credential = Struct.new(:id).new(9)

    controller.define_singleton_method(:finalize_mfa_login!) { |_|
      { status: :session_limit_hard_reject, message: "limit", http_status: :conflict }
    }
    controller.handle_successful_mfa(@user, secret_credential)

    assert_equal :hard_reject, failures.last[:reason]

    controller.define_singleton_method(:finalize_mfa_login!) { |_| { status: :restricted } }
    controller.handle_successful_mfa(@user, secret_credential)

    assert_equal [nil, {}], redirects.last

    controller.define_singleton_method(:finalize_mfa_login!) { |_| { status: :success, redirect_path: "/after" } }
    controller.define_singleton_method(:issue_bulletin!) { true }
    controller.handle_successful_mfa(@user, secret_credential)

    assert_equal "http://www.umaxica.app/?ri=jp", redirects.last.first

    controller.define_singleton_method(:issue_bulletin!) { false }
    controller.handle_successful_mfa(@user, secret_credential)

    assert_equal "http://www.umaxica.app/?ri=jp", redirects.last.first
    assert_empty redirects.last.second

    controller.define_singleton_method(:finalize_mfa_login!) { |_| { status: :unexpected } }
    controller.handle_successful_mfa(@user, secret_credential)

    assert_equal :unexpected, failures.last[:reason]

    controller.define_singleton_method(:establish_signed_in_session!) { |*|
      { status: :mfa_required, redirect_path: "/challenge" }
    }
    controller.process_standard_login(@user)

    assert_equal ["/challenge", {}], redirects.last

    controller.define_singleton_method(:establish_signed_in_session!) { |*|
      { status: :session_limit_hard_reject, message: "limit", http_status: :conflict }
    }
    controller.process_standard_login(@user)

    assert_equal :hard_reject, failures.last[:reason]

    controller.define_singleton_method(:establish_signed_in_session!) { |*| { restricted: true } }
    controller.process_standard_login(@user)

    assert_equal ["/sign/in/session", {}], redirects.last

    controller.define_singleton_method(:establish_signed_in_session!) { |*| { status: :success } }
    controller.define_singleton_method(:issue_bulletin!) { true }
    controller.process_standard_login(@user)

    assert_equal ["http://www.umaxica.app/?ri=jp", {}], redirects.last

    controller.define_singleton_method(:issue_bulletin!) { false }
    controller.process_standard_login(@user)

    assert_equal ["http://www.umaxica.app/?ri=jp", {}], redirects.last
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
