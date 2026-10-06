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

  # The page opens only for a verified sign-in flow with a browser-bound durable
  # resolution. Every case below reaches that state through the real email sign-in.
  # (adr/root-login-establishment-boundary.md).

  test "show for a pending sign-in lists the account's sessions and the cancel action" do
    enter_pending_session_limit!

    get auth_app_sign_in_session_url(ri: "jp")

    assert_response :success
    assert_equal "auth/app/sign/in/sessions/show", inertia_component
    assert_equal auth_app_sign_in_session_path(ri: "jp"), inertia_props.fetch("form").fetch("action")
    refs = inertia_props.fetch("active_sessions").fetch("items").filter_map { |item| item["ref"] }

    assert_equal ClientToken::MAX_SESSIONS_PER_USER, refs.size
    assert_equal I18n.t("sign.app.in.session.cancel_logout"), inertia_props.fetch("cancel").fetch("label")
    assert_equal auth_app_sign_in_session_path(ri: "jp"), inertia_props.fetch("cancel").fetch("action")
  end

  test "show counts only usable active sessions" do
    enter_pending_session_limit!
    ClientToken.where(user_id: @user.id).first.revoke!

    get auth_app_sign_in_session_url(ri: "jp")

    assert_response :success
    assert_equal ClientToken::MAX_SESSIONS_PER_USER - 1, inertia_props.fetch("active_sessions").fetch("items").size
  end

  test "show with active session returns forbidden" do
    active_token = create_active_session(@user)
    headers = as_user_headers_with_token(@user, active_token, host: @host)

    get auth_app_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :forbidden
  end

  test "a legacy restricted session does not open the page" do
    token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    headers = as_user_headers_with_token(@user, token, host: @host)

    get auth_app_sign_in_session_url(ri: "jp"), headers: headers

    assert_redirected_to auth_app_sign_in_url(ri: "jp")
  end

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

  test "update without selections keeps the flow pending and re-renders show" do
    enter_pending_session_limit!

    patch auth_app_sign_in_session_url(ri: "jp"), params: { revoke_refs: [] }

    assert_response :unprocessable_content
    assert_predicate latest_resolution, :open?
  end

  test "update revokes the selected session and commits the waiting sign-in" do
    first, second = enter_pending_session_limit!

    assert_difference(-> { ClientToken.where(user_id: @user.id).count }, 1) do
      patch auth_app_sign_in_session_url(ri: "jp"), params: { revoke_refs: [first.signed_ref] }
    end

    assert_response :redirect
    assert_not first.reload.currently_usable?
    assert_predicate second.reload, :currently_usable?
    issued = ClientToken.where(user_id: @user.id).order(:id).last

    assert_predicate issued, :active_status?
    assert_equal issued.id, latest_flow.token_id
  end

  test "update with an unusable ref revokes nothing and issues nothing while the limit is full" do
    enter_pending_session_limit!

    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      patch auth_app_sign_in_session_url(ri: "jp"), params: { revoke_refs: ["invalid_ref_value"] }
    end

    assert_response :success
    assert_predicate latest_resolution, :open?
  end

  test "update ignores ref belonging to another user" do
    other_user = clients(:two)
    ClientToken.where(user: other_user).delete_all
    other_token = ClientToken.create!(user: other_user, user_token_status_id: ClientTokenStatus::ACTIVE)
    enter_pending_session_limit!

    patch auth_app_sign_in_session_url(ri: "jp"), params: { revoke_refs: [other_token.signed_ref] }

    assert_predicate other_token.reload, :currently_usable?
    assert_predicate latest_resolution, :open?
  end

  test "update with ref param revokes that session and commits the waiting sign-in" do
    first, = enter_pending_session_limit!

    patch auth_app_sign_in_session_url(ri: "jp"), params: { ref: first.signed_ref }

    assert_not first.reload.currently_usable?
    assert_predicate latest_flow.token_id, :present?
  end

  test "update with invalid ref param stays on the page" do
    enter_pending_session_limit!

    patch auth_app_sign_in_session_url(ri: "jp"), params: { ref: "totally_invalid_ref" }

    assert_response :success
    assert_predicate latest_resolution, :open?
  end

  test "OIDC email verification reaches the Auth handoff without issuing an Auth session" do
    TurnstileVerifierStub.challenge_enabled = true
    first_active = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    first_active.rotate_refresh_token!
    second_active = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    second_active.rotate_refresh_token!
    [first_active, second_active].each do |token|
      token.update_columns(created_at: AuthenticationBase.login_cooldown.ago - 1.second)
    end
    email = @user.client_emails.create!(address: "cycle_limit_#{SecureRandom.hex(4)}@example.com")
    transaction = issue_sign_in_transaction
    login_challenge = transaction.login_challenge
    # Auth is ceremony-only: a direct `login_challenge` param no longer admits the ceremony (see
    # AuthCeremonyAdmission#admit_or_render_sign_ceremony!). The entry has to redeem a real
    # admission code issued by Base, same as AuthOidcEntrancesTest and AuthenticationFlowTest.
    admission_reference = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: "test-browser-nonce", base_token: nil,
    ).reference

    # `host!` (not just a per-call `Host` header) so the integration session's cookie jar
    # associates the domain-scoped session cookie with this host and resends it on
    # `follow_redirect!` -- without it, the redeemed admission's session state (
    # `oidc_authorization_login_challenge`) is silently dropped and the redirect target bridges
    # back to Base as if nothing had been admitted.
    host!(@host)
    redeem_auth_ceremony_entry!(
      auth_app_sign_in_path, reference: admission_reference,
                             params: { ri: "jp" }, headers: { "Host" => @host },
    )

    assert_response :see_other
    follow_redirect!(headers: { "Host" => @host })

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
    assert_redirected_to auth_app_sign_in_check_path(ri: "jp")

    assert_no_difference -> { ClientToken.not_revoked.where(user_id: @user.id, rotated_at: nil).count } do
      follow_redirect!
      follow_redirect!
    end
    assert_response :success

    post(auth_app_sign_oidc_handoff_path(ri: "jp"), headers: browser_headers.merge("Host" => @host))

    assert_response :success
    result_code = response.body[/name="result"[^>]+value="([^"]+)"/, 1]
    transaction_ref = response.body[/name="transaction_ref"[^>]+value="([^"]+)"/, 1]

    assert_predicate result_code, :present?
    assert_predicate transaction_ref, :present?

    cycle = ClientSignInFlow.where(principal_id: @user.id).recent_first.first

    assert_predicate cycle, :sign_in_dashboard_pending?
    assert_nil cycle.token_id
    assert_nil session[:oidc_authorization_login_challenge]

    cycle.reload
    transaction = ClientOidcAuthorizationTransaction.find_by!(login_challenge: login_challenge)

    assert_predicate cycle, :sign_in_dashboard_pending?
    assert_equal "authenticated", transaction.status
    assert_equal @user.public_id, transaction.actor_ref
    assert_nil transaction.session_ref
    assert_equal 2, ClientToken.not_revoked.where(user_id: @user.id, rotated_at: nil).count
  ensure
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

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

  test "destroy cancels only the waiting flow and redirects to login" do
    existing = enter_pending_session_limit!
    flow = latest_flow

    delete auth_app_sign_in_session_url(ri: "jp")

    assert_response :see_other
    assert_redirected_to auth_app_sign_in_url(ri: "jp")
    assert_predicate flow.reload, :sign_in_cancelled?
    assert_predicate latest_resolution, :cancelled?
    assert(existing.all? { |token| token.reload.currently_usable? })
  end

  test "destroy returns no content for json and cancels the waiting flow" do
    enter_pending_session_limit!
    flow = latest_flow

    delete auth_app_sign_in_session_url(ri: "jp", format: :json)

    assert_response :no_content
    assert_predicate flow.reload, :sign_in_cancelled?
    assert_predicate latest_resolution, :cancelled?
  end

  test "destroy with ref param revokes that session and re-renders show" do
    first, second = enter_pending_session_limit!

    delete auth_app_sign_in_session_url(ri: "jp"), params: { ref: first.signed_ref }

    assert_response :success
    assert_not first.reload.currently_usable?
    assert_predicate second.reload, :currently_usable?
  end

  test "destroy with invalid ref param does not revoke anything" do
    existing = enter_pending_session_limit!

    delete auth_app_sign_in_session_url(ri: "jp"), params: { ref: "invalid_ref" }

    assert_response :success
    assert(existing.all? { |token| token.reload.currently_usable? })
  end

  test "destroy with ref belonging to another user does not revoke" do
    other_user = clients(:two)
    ClientToken.where(user: other_user).delete_all
    other_token = ClientToken.create!(user: other_user, user_token_status_id: ClientTokenStatus::ACTIVE)
    enter_pending_session_limit!

    delete auth_app_sign_in_session_url(ri: "jp"), params: { ref: other_token.signed_ref }

    assert_predicate other_token.reload, :currently_usable?
  end

  private

  # Fills the limit, then signs in through the real email ceremony so the browser holds a verified
  # flow with a durable session-limit resolution. Returns the sessions that fill the limit.
  def enter_pending_session_limit!
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    existing = Array.new(ClientToken::MAX_SESSIONS_PER_USER) { create_active_session(@user) }
    email = @user.client_emails.create!(address: "limit_#{SecureRandom.hex(4)}@example.com")
    host!(@host)
    post(
      auth_app_sign_in_email_url(ri: "jp"),
      params: { :user_email => { address: email.address }, "cf-turnstile-response" => "t" },
    )
    pass_code = store_otp_and_return_code(email)
    patch(
      auth_app_sign_in_email_url(ri: "jp"),
      params: { "user_email" => { "pass_code" => pass_code }, "cf-turnstile-response" => "t" },
    )

    assert_predicate latest_flow, :sign_in_session_issuance_pending?
    assert_predicate latest_resolution, :open?
    existing
  ensure
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  def latest_flow
    ClientSignInFlow.where(principal_id: @user.id).recent_first.first
  end

  def latest_resolution
    ClientSessionLimitResolutionTransaction.where(sign_in_flow_id: latest_flow.id).recent_first.first
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

  def issue_sign_in_transaction
    OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_in",
      params: {
        response_type: "code",
        client_id: "core-app",
        redirect_uri: OidcClientRegistry.find!("core-app").redirect_uris.first,
        code_challenge: "challenge",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
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
          ClientToken.where(user_id: user.id).where("discard_at > ?", Time.current).order(created_at: :desc).first
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
            "discard_at > ?",
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
            "discard_at > ?",
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
    service =
      if normalized.include?("base") || normalized.include?("www.")
        "BASE"
      elsif normalized.include?("acme")
        "ACME"
      elsif normalized.include?("core")
        "CORE"
      else
        "AUTH"
      end
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
end
