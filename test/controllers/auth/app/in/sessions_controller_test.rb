# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::Sign::In::SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @user = clients(:one)
    # Clean up any existing tokens for this user
    ClientToken.where(user: @user).delete_all
    @original_allow_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @original_allow_forgery_protection
  end

  # ===================================================================
  # show -- authentication & access control
  # ===================================================================

  test "show without authentication redirects to login" do
    get auth_app_sign_in_session_url(ri: "jp"),
        headers: browser_headers.merge("Host" => @host)

    assert_response :redirect

    assert_redirected_to auth_app_sign_in_url(ri: "jp")
  end

  test "migrated settings sessions route is not served by sign" do
    with_env(
      "PRIVATE_AUTH_SERVICE_URL" => "log.umaxica.app",
      "BASE_SERVICE_URL" => "www.umaxica.app",
    ) do
      Rails.application.reload_routes!

      get(
        "https://log.umaxica.app/settings/sessions?ri=jp&token=secret&session_id=raw",
        headers: browser_headers.merge("Host" => "log.umaxica.app"),
      )

      assert_response :not_found
      assert_nil response.location
    end
  ensure
    Rails.application.reload_routes!
  end

  test "show with restricted session displays sessions" do
    create_active_session(@user)
    token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, token, host: @host)

    get auth_app_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :success
    assert_not response.redirect?
    assert_equal "auth/app/sign/in/sessions/show", inertia_component
    assert_equal auth_app_sign_in_session_path(ri: "jp"), inertia_props.fetch("form").fetch("action")
    # A session is selected by its signed reference, the same opaque value the radio button carried.
    refs = inertia_props.fetch("active_sessions").fetch("items").filter_map { |item| item["ref"] }

    assert_predicate refs, :any?
    assert_equal I18n.t("sign.app.in.session.cancel_logout"), inertia_props.fetch("cancel").fetch("label")
    # Cancelling the sign-in stays a DELETE to the session route.
    assert_equal auth_app_sign_in_session_path(ri: "jp"), inertia_props.fetch("cancel").fetch("action")
  end

  test "show counts only usable active sessions" do
    active_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    rotated_refresh = active_token.rotate_refresh_token!
    SignRefreshTokenIssuer.call(refresh_token: rotated_refresh)

    current_active = ClientToken.where(user_id: @user.id, user_token_status_id: ClientTokenStatus::ACTIVE).order(:created_at).last
    other_active = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    other_active.rotate_refresh_token!
    restricted_token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    get auth_app_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :success
    assert_equal "(2/#{ClientToken::MAX_SESSIONS_PER_USER})",
                 inertia_props.fetch("active_sessions").fetch("count_label")
    assert_not_equal active_token.public_id, current_active.public_id
  end

  test "show with active session returns forbidden" do
    active_token = create_active_session(@user)
    headers = as_user_headers_with_token(@user, active_token, host: @host)

    get auth_app_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :forbidden
  end

  # ===================================================================
  # update -- authentication & access control
  # ===================================================================

  test "update without authentication redirects to login" do
    patch auth_app_sign_in_session_url(ri: "jp"),
          params: { revoke_refs: ["some-ref"] },
          headers: browser_headers.merge(
            "Host" => @host,
            "Origin" => "http://#{@host}",
            "HTTP_ORIGIN" => "http://#{@host}",
          )

    assert_redirected_to auth_app_sign_in_url(ri: "jp")
  end

  test "update with active session returns forbidden" do
    active_token = create_active_session(@user)
    headers = as_user_headers_with_token(@user, active_token, host: @host)

    patch auth_app_sign_in_session_url(ri: "jp"),
          params: { revoke_refs: ["some-ref"] },
          headers: headers

    assert_response :forbidden
  end

  # ===================================================================
  # update -- empty selections
  # ===================================================================

  test "update without selections flashes alert and re-renders show" do
    token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, token, host: @host)

    patch auth_app_sign_in_session_url(ri: "jp"),
          params: { revoke_refs: [] },
          headers: headers

    assert_response :unprocessable_content
  end

  # ===================================================================
  # update -- revoke by refs (batch) + promotion
  # ===================================================================

  test "update revokes selected sessions and promotes restricted session" do
    active_token1 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token1.rotate_refresh_token!

    active_token2 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token2.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch auth_app_sign_in_session_url(ri: "jp"),
          params: { revoke_refs: [active_token1.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal ClientTokenStatus::ACTIVE, restricted_token.user_token_status_id

    active_token1.reload

    assert_not active_token1.currently_usable?

    # Unrevoked active session remains
    active_token2.reload

    assert_predicate active_token2, :currently_usable?
  end

  test "update revokes session but does not promote when still at limit" do
    active_token1 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token1.rotate_refresh_token!

    active_token2 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token2.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    # Send an invalid ref so nothing actually gets revoked
    patch auth_app_sign_in_session_url(ri: "jp"),
          params: { revoke_refs: ["invalid_ref_value"] },
          headers: headers

    # Still restricted -- not promoted because active_count == MAX_SESSIONS_PER_USER
    restricted_token.reload

    assert_equal ClientTokenStatus::RESTRICTED, restricted_token.user_token_status_id
    assert_response :success # re-renders show
  end

  test "update skips current session ref in batch revoke" do
    # Need 2 active sessions to prevent auto-promotion after no-op revoke
    active_token1 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token1.rotate_refresh_token!

    active_token2 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token2.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch auth_app_sign_in_session_url(ri: "jp"),
          params: { revoke_refs: [restricted_token.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal ClientTokenStatus::RESTRICTED, restricted_token.user_token_status_id
    assert_predicate restricted_token, :currently_usable?
  end

  test "update ignores ref belonging to another user" do
    other_user = clients(:two)
    ClientToken.where(user: other_user).delete_all
    other_token = ClientToken.create!(user: other_user, user_token_status_id: ClientTokenStatus::ACTIVE)
    other_token.rotate_refresh_token!

    restricted_token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch auth_app_sign_in_session_url(ri: "jp"),
          params: { revoke_refs: [other_token.signed_ref] },
          headers: headers

    other_token.reload

    assert_predicate other_token, :currently_usable?
  end

  # ===================================================================
  # update -- revoke by single ref param
  # ===================================================================

  test "update with ref param revokes specific session" do
    active_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch auth_app_sign_in_session_url(ri: "jp"),
          params: { ref: active_token.signed_ref },
          headers: headers

    active_token.reload

    assert_not active_token.currently_usable?

    restricted_token.reload

    assert_equal ClientTokenStatus::ACTIVE, restricted_token.user_token_status_id
  end

  test "update with ref param rejects revoking current session" do
    # Need 2 active sessions to prevent auto-promotion
    active_token1 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token1.rotate_refresh_token!

    active_token2 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token2.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch auth_app_sign_in_session_url(ri: "jp"),
          params: { ref: restricted_token.signed_ref },
          headers: headers

    restricted_token.reload

    assert_equal ClientTokenStatus::RESTRICTED, restricted_token.user_token_status_id
    assert_predicate restricted_token, :currently_usable?
  end

  test "update with invalid ref param flashes alert and stays on page" do
    # Need 2 active sessions to prevent auto-promotion
    active_token1 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token1.rotate_refresh_token!

    active_token2 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token2.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch auth_app_sign_in_session_url(ri: "jp"),
          params: { ref: "totally_invalid_ref" },
          headers: headers

    assert_response :success # re-renders show
    restricted_token.reload

    assert_equal ClientTokenStatus::RESTRICTED, restricted_token.user_token_status_id
  end

  # ===================================================================
  # update -- redirect after promotion
  # ===================================================================

  test "update promotes and redirects to settings path by default" do
    active_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch auth_app_sign_in_session_url(ri: "jp"),
          params: { revoke_refs: [active_token.signed_ref] },
          headers: headers

    assert_response :redirect
    assert_match %r{\Ahttps://jump\.umaxica\.net/}, response.location
    assert_includes response.location, "rt="
  end

  test "update promotes pending email OIDC sign-in cycle and signs in Sign while preserving callback capacity" do
    TurnstileVerifierStub.challenge_enabled = true
    first_active = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    first_active.rotate_refresh_token!
    second_active = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    second_active.rotate_refresh_token!
    [first_active, second_active].each do |token|
      token.update_columns(created_at: AuthenticationBase.login_cooldown.ago - 1.second)
    end
    email = @user.client_emails.create!(address: "cycle_limit_#{SecureRandom.hex(4)}@example.com")
    login_challenge = issue_login_challenge

    get(auth_app_sign_in_url(ri: "jp", login_challenge: login_challenge), headers: { "Host" => @host })

    assert_response :success

    post(
      auth_app_sign_in_email_url(ri: "jp"),
      params: {
        :client_email => { address: email.address },
        "cf-turnstile-response" => "test_token",
      },
      headers: { "Host" => @host },
    )

    assert_predicate response, :redirect?, response.body

    pass_code = store_otp_and_return_code(email)
    patch(
      auth_app_sign_in_email_url(ri: "jp"),
      params: { client_email: { pass_code: pass_code } },
      headers: { "Host" => @host },
    )

    assert_response :redirect
    assert_redirected_to auth_app_sign_in_session_path(ri: "jp")

    cycle = ClientSignInFlow.where(principal_id: @user.id).recent_first.first

    assert_predicate cycle, :sign_in_session_limit_pending?

    assert_no_difference -> { ClientToken.not_revoked.where(user_id: @user.id, rotated_at: nil).count } do
      patch(
        auth_app_sign_in_session_url(ri: "jp"),
        params: { revoke_refs: [first_active.signed_ref] },
        headers: browser_headers.merge("Host" => @host),
      )
    end

    assert_response :redirect
    assert_match %r{/sign/in/check\?ri=jp}, response.location
    follow_redirect!(headers: browser_headers.merge("Host" => @host))

    assert_response :redirect
    assert_match %r{/welcome\?ri=jp}, response.location
    assert_predicate response.headers["Set-Cookie"].to_s, :present?
    assert_nil session[:oidc_authorization_login_challenge]

    cycle.reload
    issued_session = ClientToken.find(cycle.token_id)
    transaction = ClientOidcAuthorizationTransaction.find_by!(login_challenge: login_challenge)

    assert_predicate cycle, :sign_in_dashboard_pending?
    assert_predicate issued_session, :active?
    assert_equal "pending", transaction.status
    assert_nil transaction.actor_ref
    assert_nil transaction.session_ref
    assert_nil transaction.auth_method
    assert_equal 2, ClientToken.not_revoked.where(user_id: @user.id, rotated_at: nil).count
  ensure
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "update with pt param redirects to the requested path" do
    active_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    pt = "/settings"

    patch auth_app_sign_in_session_url(ri: "jp", pt: pt),
          params: { revoke_refs: [active_token.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal ClientTokenStatus::ACTIVE, restricted_token.user_token_status_id

    assert_response :redirect
    assert_match %r{\Ahttps://jump\.umaxica\.net/}, response.location
    assert_includes response.location, "rt="
  end

  test "update with invalid pt param falls back to default path" do
    active_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch auth_app_sign_in_session_url(ri: "jp", pt: "not-a-token"),
          params: { revoke_refs: [active_token.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal ClientTokenStatus::ACTIVE, restricted_token.user_token_status_id

    assert_response :redirect
    assert_match %r{\Ahttps://jump\.umaxica\.net/}, response.location
    assert_includes response.location, "rt="
  end

  # ===================================================================
  # destroy -- authentication & access control
  # ===================================================================

  test "destroy without authentication redirects to login" do
    delete auth_app_sign_in_session_url(ri: "jp"),
           headers: browser_headers.merge(
             "Host" => @host,
             "Origin" => "http://#{@host}",
             "HTTP_ORIGIN" => "http://#{@host}",
           )

    assert_redirected_to auth_app_sign_in_url(ri: "jp")
  end

  test "destroy with active session returns forbidden" do
    active_token = create_active_session(@user)
    headers = as_user_headers_with_token(@user, active_token, host: @host)

    delete auth_app_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :forbidden
  end

  # ===================================================================
  # destroy -- cancel restricted session (no ref)
  # ===================================================================

  test "destroy cancels restricted session and redirects to login" do
    token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, token, host: @host)

    delete auth_app_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :see_other
    assert_redirected_to auth_app_sign_in_url(ri: "jp")

    token.reload

    assert_not token.currently_usable?
    assert_equal ClientTokenStatus::REVOKED, token.user_token_status_id
  end

  test "delete session route cancels restricted session and redirects to login" do
    token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, token, host: @host)

    delete auth_app_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :see_other
    assert_redirected_to auth_app_sign_in_url(ri: "jp")

    token.reload

    assert_not token.currently_usable?
    assert_equal ClientTokenStatus::REVOKED, token.user_token_status_id
  end

  test "delete session route returns no content for json" do
    token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, token, host: @host)

    delete auth_app_sign_in_session_url(ri: "jp", format: :json), headers: headers

    assert_response :no_content

    token.reload

    assert_not token.currently_usable?
    assert_equal ClientTokenStatus::REVOKED, token.user_token_status_id
  end

  # ===================================================================
  # destroy -- revoke specific session (with ref)
  # ===================================================================

  test "destroy with ref param revokes specific session and re-renders show" do
    active_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    delete auth_app_sign_in_session_url(ri: "jp"),
           params: { ref: active_token.signed_ref },
           headers: headers

    assert_response :success # re-renders show, does not redirect

    active_token.reload

    assert_not active_token.currently_usable?

    restricted_token.reload

    assert_equal ClientTokenStatus::RESTRICTED, restricted_token.user_token_status_id
  end

  test "destroy with ref param rejects revoking current session" do
    restricted_token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    delete auth_app_sign_in_session_url(ri: "jp"),
           params: { ref: restricted_token.signed_ref },
           headers: headers

    assert_response :success
    restricted_token.reload

    assert_equal ClientTokenStatus::RESTRICTED, restricted_token.user_token_status_id
    assert_predicate restricted_token, :currently_usable?
  end

  test "destroy with invalid ref param does not revoke anything" do
    restricted_token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    delete auth_app_sign_in_session_url(ri: "jp"),
           params: { ref: "invalid_ref" },
           headers: headers

    assert_response :success
    restricted_token.reload

    assert_equal ClientTokenStatus::RESTRICTED, restricted_token.user_token_status_id
  end

  test "destroy with ref belonging to another user does not revoke" do
    other_user = clients(:two)
    ClientToken.where(user: other_user).delete_all
    other_token = ClientToken.create!(user: other_user, user_token_status_id: ClientTokenStatus::ACTIVE)
    other_token.rotate_refresh_token!

    restricted_token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    delete auth_app_sign_in_session_url(ri: "jp"),
           params: { ref: other_token.signed_ref },
           headers: headers

    other_token.reload

    assert_predicate other_token, :currently_usable?
  end

  # ===================================================================
  # restricted session expiry (boundary analysis)
  # ===================================================================

  test "restricted session at 14 minutes is still accessible (boundary: within TTL)" do
    token = create_restricted_session(@user, discarded_at: 15.minutes.from_now)
    headers = as_user_headers_with_token(@user, token, host: @host, expires_at: 30.minutes.from_now)

    travel 14.minutes do
      get auth_app_sign_in_session_url(ri: "jp"), headers: headers

      assert_response :success
    end

    assert_response :success
    token.reload

    assert_equal ClientTokenStatus::RESTRICTED, token.user_token_status_id
  end

  test "restricted session expires after 15 minutes and is locked on in/session" do
    token = create_restricted_session(@user, discarded_at: 15.minutes.from_now)
    headers = as_user_headers_with_token(@user, token, host: @host)
    logs = []

    travel 16.minutes do
      Rails.logger.stub(
        :info, ->(*args) do
                 message = args.first
                 logs << JSON.parse(message, symbolize_names: true) if message.present?
               end,
      ) do
        get auth_app_sign_in_session_url(ri: "jp"), headers: headers
      end
    end

    assert_response :locked
    assert_equal "きんそくじこうです", response.body
    assert_not response.redirect?
    assert_includes logs.pluck(:event), "session.restricted.expired"
  end

  # ===================================================================
  # RestrictedSessionGuard -- non-session routes blocked
  # ===================================================================

  test "restricted session is blocked on non-session base app routes" do
    token = create_restricted_session(@user)
    base_host = ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost")
    headers = {
      "Host" => base_host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    get auth_app_dashboard_url(ri: "jp", host: base_host), headers: headers

    assert_response :bad_request
  end

  private

  def create_restricted_session(user, discarded_at: nil)
    token = ClientToken.create!(
      user: user,
      user_token_status_id: ClientTokenStatus::RESTRICTED,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    token.rotate_refresh_token!(discarded_at: discarded_at)
    token
  end

  def create_active_session(user)
    token = ClientToken.create!(
      user: user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    token.rotate_refresh_token!
    token
  end

  def issue_login_challenge
    OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_in",
      params: {
        response_type: "code",
        client_id: "core-next-rp",
        redirect_uri: OidcClientRegistry.find!("core-next-rp").redirect_uris.first,
        code_challenge: "challenge",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction.login_challenge
  end

  def store_otp_and_return_code(email)
    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    pass_code = ROTP::HOTP.new(otp_private_key).at(otp_counter).to_s
    email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)
    pass_code
  end

  def as_user_headers_with_token(user, token, host:, expires_at: 30.minutes.from_now)
    access_token = AuthenticationToken.encode(
      user,
      host: host,
      session_public_id: token.public_id,
      expires_at: expires_at,
      jwt_issuer_id: jwt_issuer_id_for_test_host(host, "client"),
    )
    browser_headers.merge(
      "Host" => host,
      "Origin" => "http://#{host}",
      "HTTP_ORIGIN" => "http://#{host}",
      "Authorization" => "Bearer #{access_token}",
      "Cookie" => [
        "csrf_token=test_csrf_token",
        "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{access_token}",
      ].join("; "),
    )
  end

  def with_env(vars)
    original = {}
    vars.each_key { |key| original[key] = ENV[key] }

    vars.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    original.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
  private

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)

    if user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"
      token =
        if session_public_id.present?
          ClientToken.find_by(public_id: session_public_id)
        else
          ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
        end
      token ||= ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

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

    if staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"
      token =
        if session_public_id.present?
          OperatorToken.find_by(public_id: session_public_id)
        else
          OperatorToken.where(staff_id: staff.id).where(
            "discarded_at > ?",
            Time.current,
          ).order(created_at: :desc).first
        end
      token ||= OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

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
    VisitorTokenBindingMethod.ensure_defaults! if defined?(VisitorTokenBindingMethod)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB) if defined?(VisitorTokenKind)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)

    if visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"
      token =
        if session_public_id.present?
          VisitorToken.find_by(public_id: session_public_id)
        else
          VisitorToken.where(visitor_id: visitor.id).where(
            "discarded_at > ?",
            Time.current,
          ).order(created_at: :desc).first
        end
      token ||= VisitorToken.create!(visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

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
end

# DAMP auth header helpers for this test class.
class Auth::App::Sign::In::SessionsControllerTest
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

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
end
