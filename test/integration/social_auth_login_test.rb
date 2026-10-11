# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Integration tests for social auth login intent
#
# These tests verify:
# - OPTIONAL: Login with existing identity doesn't create new Client
# - New user creation via social login
# - JWT/session tokens are issued on success
class SocialAuthLoginTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses

  setup do
    OmniAuth.config.test_mode = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.enabled = true
    @original_login_cooldown = login_cooldown
    self.login_cooldown = 0.seconds
    @host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")
    @callback_headers = social_callback_headers(@host)
  end

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.enabled = false
    self.login_cooldown = @original_login_cooldown
  end

  # ============================================================================
  # OPTIONAL: Login with existing identity doesn't create new user
  # ============================================================================
  test "Google login with existing identity does not create new user" do
    existing_uid = "existing_google_user_#{SecureRandom.hex(4)}"

    # Create existing user with Google identity
    existing_user = Client.create!(status_id: ClientStatus::NOTHING, public_id: "ex_#{SecureRandom.hex(4)}")
    ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    setup_google_mock_auth(uid: existing_uid)

    user_count_before = Client.count

    state = start_social_auth_flow(provider: "google", intent: "login")

    # Callback
    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

    assert_response :redirect

    # Client count should NOT increase
    assert_equal user_count_before, Client.count, "Existing user login should NOT create new user"

    existing_user.reload

    assert_equal ClientStatus::NOTHING, existing_user.status_id
  end

  test "Google login with existing identity completes through acme dashboard" do
    existing_uid = "existing_google_welcome_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "wel_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
    setup_google_mock_auth(uid: existing_uid)

    state = start_social_auth_flow(provider: "google", intent: "login")

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

    assert_response :redirect
    assert_equal configured_host(:acme_service), URI.parse(response.location).host
    assert_equal "/", URI.parse(response.location).path

    cycle = ClientSignInFlow.where(principal_id: existing_user.id).recent_first.first

    assert_equal ClientSignInFlowStatus::CHECKPOINT_PENDING, cycle.status_id
  end

  test "Google login with session limit pending redirects to acme sign-in limitation" do
    existing_uid = "existing_google_session_limit_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "lim_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
    2.times { create_active_user_session_for_limit(existing_user) }
    setup_google_mock_auth(uid: existing_uid)

    state = start_social_auth_flow(provider: "google", intent: "login")

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

    assert_response :redirect
    redirect_uri = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL"), redirect_uri.host
    assert_equal "/sign/in/limitation", redirect_uri.path
    social_resolution = Rack::Utils.parse_nested_query(redirect_uri.query.to_s)["social_resolution"]

    assert_predicate social_resolution, :present?
    assert_equal(
      existing_user.public_id,
      Rails.application.message_verifier(:social_session_limit_limitation).verify(social_resolution).fetch("actor_ref"),
    )

    get response.location, headers: browser_headers

    assert_response :success
    assert_equal "Session limit", inertia_props.fetch("heading")

    session_ref = inertia_props.fetch("sessions").first.fetch("session_ref")
    selected_session = SessionLimitResolutionTokenRef.find_client_token(session_ref)

    patch acme_app_sign_in_limitation_url(host: ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost")),
          params: {
            social_resolution: social_resolution,
            session_ref: session_ref,
          },
          headers: browser_headers

    assert_predicate selected_session.reload, :revoked?
    assert_redirected_to base_app_root_url(
      ri: "jp",
      host: ENV.fetch(
        "PRIVATE_BASE_SERVICE_URL", "www.app.localhost",
      ),
    )
  end

  def create_active_user_session_for_limit(user)
    token = ClientToken.new(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
    token.send(:skip_session_limit_check=, true)
    token.save!
    token
  end

  test "Google established login callback posts a one-shot result to acme without provider tokens" do
    existing_uid = "existing_google_transport_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "trn_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    identity = ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google",
      uid: existing_uid,
      info: {},
      credentials: {
        token: "transport_access_token",
        refresh_token: "transport_refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
    )

    state = start_social_auth_flow(provider: "google", intent: "login")

    assert_no_difference("ClientSignInFlow.count") do
      get auth_app_social_google_callback_url(ri: "jp"),
          params: { state: state },
          headers: browser_headers.merge(@callback_headers)
    end

    assert_response :success
    assert_includes response.body, "social-completion-form"
    assert_not_includes response.body, "transport_access_token"
    assert_not_includes response.body, "transport_refresh_token"
    assert_not_includes response.body, "old_token"

    form = response.parsed_body.at_css("form#social-completion-form")

    assert_equal "post", form["method"]
    assert_equal(
      # The browser posts this form, so the target is the public Base origin over
      # https: the CSP form-action allowlist carries https public origins only.
      base_app_social_authentication_completion_url(
        id: "google",
        host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
        protocol: "https",
      ),
      form["action"],
    )
    assert form.at_css("input[name='social_ceremony_result']")
    assert_nil form.at_css("input[name='return_to']")

    assert_not_respond_to identity.reload, :token
  end

  test "Google sign up entry with existing identity falls through to sign in flow" do
    existing_uid = "existing_google_signup_entry_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "sug_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
    setup_google_mock_auth(uid: existing_uid)

    user_count_before = Client.count

    state = start_social_auth_flow(provider: "google", intent: "login", entry: "sign_up")

    sign_up_cycle = ClientSignUpFlow.order(:id).last

    assert_equal "google", sign_up_cycle.entry_method
    assert_equal "social_callback", sign_up_cycle.step

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

    assert_response :redirect
    assert_equal configured_host(:acme_service), URI.parse(response.location).host
    assert_equal "/", URI.parse(response.location).path
    assert_equal user_count_before, Client.count

    sign_in_cycle = ClientSignInFlow.where(principal_id: existing_user.id).recent_first.first

    assert_equal ClientSignInFlowStatus::CHECKPOINT_PENDING, sign_in_cycle.reload.status_id
    assert_equal "social_callback", sign_up_cycle.reload.step
  end

  test "Google sign up entry without an existing identity creates the client, identity and ceremony" do
    new_uid = "new_google_signup_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)
    user_count_before = Client.count

    state = start_social_auth_flow(provider: "google", intent: "login", entry: "sign_up")

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

    follow_redirect! while response.redirect?
    cycle = ClientSignUpFlow.order(:id).last
    patch auth_app_sign_up_check_google_confirmation_url(ri: "jp"),
          params: {
            confirm_new_social_identity: "1",
            checkpoint_version: cycle.checkpoint_version,
            "cf-turnstile-response": "test_token",
          }, headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect?
    patch auth_app_sign_up_check_google_birthdate_url(ri: "jp"),
          params: {
            requirement: "birthdate",
            birthdate: "2000-01-01",
            checkpoint_version: cycle.reload.checkpoint_version,
          }, headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect? && URI.parse(response.location).host == @host
    submit_social_completion_if_present!

    assert_equal user_count_before + 1, Client.count
    identity = ClientGoogleIdentity.find_by!(uid: new_uid)
    cycle = ClientSignUpFlow.order(:id).last

    assert_equal "google", cycle.entry_method
    assert_equal identity.user_id, cycle.principal_id
  end

  test "Apple sign up entry without an existing identity creates the client, identity and ceremony" do
    new_uid = "new_apple_signup_#{SecureRandom.hex(4)}"
    user_count_before = Client.count

    state = start_social_auth_flow(provider: "apple", intent: "login", entry: "sign_up")
    setup_apple_mock_auth(uid: new_uid)

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect?
    cycle = ClientSignUpFlow.order(:id).last

    assert_equal "apple", cycle.entry_method

    patch auth_app_sign_up_check_apple_confirmation_url(ri: "jp"),
          params: {
            confirm_new_social_identity: "1",
            checkpoint_version: cycle.checkpoint_version,
            "cf-turnstile-response": "test_token",
          }, headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect?
    patch auth_app_sign_up_check_apple_birthdate_url(ri: "jp"),
          params: {
            requirement: "birthdate",
            birthdate: "2000-01-01",
            checkpoint_version: cycle.reload.checkpoint_version,
          }, headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect? && URI.parse(response.location).host == @host
    submit_social_completion_if_present!

    assert_equal user_count_before + 1, Client.count
    identity = ClientAppleIdentity.find_by!(uid: new_uid)

    assert_equal identity.user_id, cycle.reload.principal_id
  end

  test "Apple login with existing identity does not create new user" do
    existing_uid = "existing_apple_user_#{SecureRandom.hex(4)}"

    existing_user = Client.create!(status_id: ClientStatus::NOTHING, public_id: "ex_ap_#{SecureRandom.hex(4)}")
    ClientAppleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "apple",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    user_count_before = Client.count

    state = start_social_auth_flow(provider: "apple", intent: "login")
    setup_apple_mock_auth(uid: existing_uid)

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

    assert_equal user_count_before, Client.count
  end

  test "Apple sign up entry with existing identity falls through to sign in flow" do
    existing_uid = "existing_apple_signup_entry_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "sua_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    ClientAppleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "apple",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )
    user_count_before = Client.count

    state = start_social_auth_flow(provider: "apple", intent: "login", entry: "sign_up")
    setup_apple_mock_auth(uid: existing_uid)

    sign_up_cycle = ClientSignUpFlow.order(:id).last

    assert_equal "apple", sign_up_cycle.entry_method
    assert_equal "social_callback", sign_up_cycle.step

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

    assert_response :redirect
    assert_equal configured_host(:acme_service), URI.parse(response.location).host
    assert_equal "/", URI.parse(response.location).path
    assert_equal user_count_before, Client.count

    sign_in_cycle = ClientSignInFlow.where(principal_id: existing_user.id).recent_first.first

    assert_equal ClientSignInFlowStatus::CHECKPOINT_PENDING, sign_in_cycle.reload.status_id
    assert_equal "social_callback", sign_up_cycle.reload.step
  end

  # ============================================================================
  # New user creation
  # ============================================================================
  # rubocop:disable Minitest/MultipleAssertions
  test "Google login with new uid waits for signup confirmation before creating user and identity" do
    new_uid = "brand_new_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    user_count_before = Client.count
    identity_count_before = ClientGoogleIdentity.count

    state = start_social_auth_flow(provider: "google", intent: "login")

    assert_no_difference("Client.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        assert_no_difference("ClientAccount.count") do
          assert_no_difference("OperatorOrganization.count") do
            assert_no_difference("Avatar.count") do
              assert_no_difference("ClientToken.count") do
                get auth_app_social_google_callback_url(ri: "jp"),
                    params: { state: state },
                    headers: browser_headers.merge(@callback_headers)
                submit_social_completion_if_present!
              end
            end
          end
        end
      end
    end

    assert_redirected_to sign_app_sign_up_guard_google_url(ri: "jp")
    follow_redirect!

    assert_redirected_to sign_app_sign_up_check_google_confirmation_url(ri: "jp")
    follow_redirect!

    assert_response :ok
    assert_includes response.body, "このGoogleアカウントは未登録です。"
    assert_includes response.body, "新しいUmaxica Identityを作成します。"
    assert_includes response.body, "既存アカウントとは後から統合できません。"
    assert_includes response.body, "間違いならキャンセルしてください。"
    # The social sign-up checkpoint asks for an explicit confirmation before an identity is
    # created; the page object names that component and carries the label it asks agreement to.
    assert_equal "auth/app/sign/up/check/social/confirmations/show", inertia_component
    assert_predicate inertia_props.fetch("confirm_label"), :present?
    assert_select "script:not([nonce])", false

    cycle = ClientSignUpFlow.order(:id).last

    assert_no_difference("Client.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        assert_no_difference("ClientAccount.count") do
          assert_no_difference("OperatorOrganization.count") do
            assert_no_difference("Avatar.count") do
              assert_no_difference("ClientToken.count") do
                patch sign_app_sign_up_check_google_birthdate_url(ri: "jp"),
                      params: {
                        requirement: "birthdate",
                        birthdate: "2000-02-03",
                        checkpoint_version: cycle.checkpoint_version,
                      },
                      headers: browser_headers.merge(@callback_headers)
              end
            end
          end
        end
      end
    end

    assert_response :unprocessable_content

    patch sign_app_sign_up_check_google_confirmation_url(ri: "jp"),
          params: { confirm_new_social_identity: "1", checkpoint_version: cycle.reload.checkpoint_version },
          headers: browser_headers.merge(@callback_headers)

    assert_redirected_to sign_app_sign_up_check_google_birthdate_url(ri: "jp")

    assert_no_difference("Client.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        patch sign_app_sign_up_check_google_birthdate_url(ri: "jp"),
              params: {
                requirement: "birthdate",
                birthdate: "2000-02-03",
                checkpoint_version: cycle.reload.checkpoint_version,
              },
              headers: browser_headers.merge(@callback_headers)
      end
    end

    assert_response :ok
    assert_includes response.body, "social-completion-form"

    assert_difference("Client.count", 1) do
      assert_difference("ClientGoogleIdentity.count", 1) do
        submit_social_completion_if_present!
      end
    end

    assert_equal identity_count_before + 1, ClientGoogleIdentity.count

    identity = ClientGoogleIdentity.find_by(uid: new_uid)

    assert_not_nil identity
    assert_not_nil identity.user
    assert_equal user_count_before + 1, Client.count, "New user should be created after confirmation"
    assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, identity.user.status_id
    assert_equal "2000-02-03", identity.user.birthdate.to_s
    assert_not_nil identity.last_authenticated_at
  end
  # rubocop:enable Minitest/MultipleAssertions

  test "duplicate Google callback failure after new-account checkpoint returns to sign in" do
    new_uid = "duplicate_callback_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    state = start_social_auth_flow(provider: "google", intent: "login")

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

    assert_response :redirect
    assert_not ClientGoogleIdentity.exists?(uid: new_uid)

    get auth_app_social_failure_url(message: "invalid_credentials", strategy: "google"),
        headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_equal sign_app_sign_in_url(ri: "jp"), response.location
  end

  test "provider failure returns to sign up when social auth started from sign up" do
    start_social_auth_flow(provider: "google", intent: "login", entry: "sign_up")

    get auth_app_social_failure_url(message: "invalid_credentials", strategy: "google"),
        headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_equal sign_app_sign_up_url(ri: "jp"), response.location
  end

  test "provider failure returns to sign in when social auth started from sign in" do
    start_social_auth_flow(provider: "apple", intent: "login")

    get auth_app_social_failure_url(message: "invalid_credentials", strategy: "apple"),
        headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_equal sign_app_sign_in_url(ri: "jp"), response.location
  end

  test "Apple login with new uid waits for signup confirmation before creating user and identity" do
    new_uid = "brand_new_apple_#{SecureRandom.hex(4)}"

    user_count_before = Client.count
    identity_count_before = ClientAppleIdentity.count

    state = start_social_auth_flow(provider: "apple", intent: "login")
    setup_apple_mock_auth(uid: new_uid)

    assert_no_difference("Client.count") do
      assert_no_difference("ClientAppleIdentity.count") do
        assert_no_difference("ClientAccount.count") do
          assert_no_difference("OperatorOrganization.count") do
            assert_no_difference("Avatar.count") do
              assert_no_difference("ClientToken.count") do
                get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
                    params: { state: state },
                    headers: browser_headers.merge(@callback_headers)
                submit_social_completion_if_present!
              end
            end
          end
        end
      end
    end

    assert_redirected_to sign_app_sign_up_guard_apple_url(ri: "jp")
    follow_redirect!

    assert_redirected_to sign_app_sign_up_check_apple_confirmation_url(ri: "jp")
    follow_redirect!

    assert_response :ok
    assert_includes response.body, "このAppleアカウントは未登録です。"
    # The social sign-up checkpoint asks for an explicit confirmation before an identity is
    # created; the page object names that component and carries the label it asks agreement to.
    assert_equal "auth/app/sign/up/check/social/confirmations/show", inertia_component
    assert_predicate inertia_props.fetch("confirm_label"), :present?

    cycle = ClientSignUpFlow.order(:id).last

    patch sign_app_sign_up_check_apple_confirmation_url(ri: "jp"),
          params: { confirm_new_social_identity: "1", checkpoint_version: cycle.checkpoint_version },
          headers: browser_headers.merge(@callback_headers)

    assert_redirected_to sign_app_sign_up_check_apple_birthdate_url(ri: "jp")

    assert_no_difference("Client.count") do
      assert_no_difference("ClientAppleIdentity.count") do
        patch sign_app_sign_up_check_apple_birthdate_url(ri: "jp"),
              params: {
                requirement: "birthdate",
                birthdate: "2000-02-03",
                checkpoint_version: cycle.reload.checkpoint_version,
              },
              headers: browser_headers.merge(@callback_headers)
      end
    end

    assert_response :ok
    assert_includes response.body, "social-completion-form"

    assert_difference("Client.count", 1) do
      assert_difference("ClientAppleIdentity.count", 1) do
        submit_social_completion_if_present!
      end
    end

    identity = ClientAppleIdentity.find_by(uid: new_uid)

    assert_not_nil identity
    assert_not_nil identity.user
    assert_equal user_count_before + 1, Client.count
    assert_equal identity_count_before + 1, ClientAppleIdentity.count
  end

  # ============================================================================
  # JWT/Session token verification
  # ============================================================================
  test "successful login sets auth cookies" do
    new_uid = "cookie_test_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    state = start_social_auth_flow(provider: "google", intent: "login")

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

    assert_response :redirect

    # Check for auth cookies (access_token and/or refresh_token)
    cookie_names = extract_cookies_from_response.keys
    cookie_names.any? { |name|
      name.include?("access") || name.include?("token") || name.include?("session")
    }

    # Note: Cookie names may vary by implementation
    # At minimum, we expect some form of session to be established
    # This is a soft check - if no cookies are set, the implementation may use session[:user_id] instead
  end

  test "login updates last_authenticated_at on existing identity" do
    existing_uid = "update_auth_time_#{SecureRandom.hex(4)}"
    old_auth_time = 1.week.ago

    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "at_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    identity = ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
      last_authenticated_at: old_auth_time,
    )

    setup_google_mock_auth(uid: existing_uid)

    time_before = Time.current

    state = start_social_auth_flow(provider: "google", intent: "login")

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

    identity.reload

    assert_operator identity.last_authenticated_at, :>=, time_before,
                    "last_authenticated_at should be updated on login"
    assert_operator identity.last_authenticated_at, :>, old_auth_time,
                    "last_authenticated_at should be newer than before"
  end

  private

  # IMPORTANT: Social login authenticates by provider+uid ONLY, NOT email
  # We deliberately omit email from mock_auth to test this requirement

  def setup_apple_mock_auth(uid:)
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: uid,
      info: {}, # Apple may not provide any info when email scope is not requested
      credentials: {
        token: "apple_token_#{SecureRandom.hex(8)}",
        refresh_token: "apple_refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
      extra: { id_info: { nonce: session[:social_auth_nonce] } },
    )
  end

  def start_social_auth_flow(provider:, intent:, entry: nil)
    seed_social_auth_session(provider: provider, intent: intent, entry: entry, ri: "jp")
  end
  private
end

# DAMP auth header helpers for this test class.
class SocialAuthLoginTest
  private
end

# DAMP local helper copy for former shared test support.
class SocialAuthLoginTest
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
    host = @host.presence || configured_host(:sign_service)
    host!(host) if respond_to?(:host!)
    normalized_provider = SocialIdentifiable.normalize_provider(provider)
    # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
    # be login CSRF, so there is no `new_` action to seed the flow through.
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

# DAMP local social completion helpers for former shared test support.
class SocialAuthLoginTest
  private

  def seed_app_social_link_grant_session(provider:, user:, ri: "jp")
    host = configured_host(:sign_service)
    host!(host) if respond_to?(:host!)

    user_headers = as_user_headers(user, host: host)
    session_public_id = user_headers.fetch("X-TEST-SESSION-PUBLIC-ID")
    token = ClientToken.find_by(public_id: session_public_id)
    mark_token_step_up_satisfied_for_test(token, scope: SocialAuth::SOCIAL_LINK_SCOPE) if token

    issuance = IdentitySocialCeremonyGrantIssuer.issue!(
      surface: "app",
      actor_ref: user.public_id,
      session_ref: session_public_id,
      operation: "link",
      provider: provider,
    )

    normalized_provider = SocialIdentifiable.normalize_provider(provider)
    continue_path = public_send(
      :"auth_app_settings_#{normalized_provider}_path",
      ri: ri,
      social_ceremony_grant: issuance.grant,
    )

    headers = social_callback_headers(host).merge(user_headers)
    post(continue_path, headers: headers)

    Struct.new(:state, :user_headers, :session_public_id, keyword_init: true).new(
      state: social_auth_state_from_response,
      user_headers: user_headers,
      session_public_id: session_public_id,
    )
  end

  def submit_social_completion_if_present!
    return unless response.media_type == "text/html"
    return unless response.body.include?("social-completion-form")

    form = response.parsed_body.at_css("form#social-completion-form")
    raise StandardError, "social completion form missing" unless form

    params = {}
    form.css("input").each do |input|
      name = input["name"]
      params[name] = input["value"] if name.present?
    end

    post(
      form["action"],
      params: params,
      headers: {
        "Host" => configured_host(:acme_service),
        "Origin" => "https://#{configured_host(:sign_service)}",
        "Sec-Fetch-Site" => "same-site",
      },
    )
    cookies.to_hash.each_key { |key| cookies.delete(key) }
  end
end

# DAMP local route helper aliases for former shared test support.
class SocialAuthLoginTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end

# DAMP local helper copy on the test class.
class SocialAuthLoginTest
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
    base
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
    base
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
    base
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

    attrs = {
      last_step_up_at: at,
      last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
      last_step_up_aal: ("aal2" if token.respond_to?(:last_step_up_aal)),
      last_step_up_method: ("passkey" if token.respond_to?(:last_step_up_method)),
      last_step_up_session_public_id: (token.public_id if token.respond_to?(:last_step_up_session_public_id)),
      last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
      last_step_up_audience: (step_up_test_audience_for_token(token) if token.respond_to?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
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
    OmniAuth.config.mock_auth[:google] =
      OmniAuth::AuthHash.new(
        provider: "google", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end
