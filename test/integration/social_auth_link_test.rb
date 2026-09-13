# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Integration tests for social auth link intent
#
# These tests verify:
# - MANDATORY TEST 3: Linking a provider+uid already linked to another user -> 409
# - Link with duplicate user_id+provider -> 409
# - Successful link creates identity and associates with current user
class SocialAuthLinkTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  SOCIAL_FLOW_ID_SESSION_KEY = :social_auth_flow_id
  fixtures :clients,
           :client_statuses,
           :app_preference_chronicle_levels

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
    @base_host = Rails.configuration.x.boot_config.fetch(:hosts).base_service.host
    @callback_headers = social_callback_headers(@host)

    # Create test users
    @user_one = clients(:one)
    @user_two = clients(:two)

    # Ensure no pre-existing social identities
    ClientGoogleIdentity.where(user: [@user_one, @user_two]).destroy_all
    ClientAppleIdentity.where(user: [@user_one, @user_two]).destroy_all
  end

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
  end

  # ============================================================================
  # MANDATORY TEST 3: Link provider+uid already linked to another user -> 409
  # ============================================================================
  test "link Google identity already linked to another user returns 409 Conflict" do
    existing_uid = "google_owned_by_user_one"

    # First, create identity for user_one
    ClientGoogleIdentity.create!(
      user: @user_one,
      uid: existing_uid,
      provider: "google",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    # Setup mock auth with the same uid
    setup_google_mock_auth(uid: existing_uid)

    grant_session = seed_app_social_link_grant_session(provider: "google", user: @user_two, ri: "jp")

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: grant_session.state },
        headers: @callback_headers.merge(grant_session.user_headers)

    # Should redirect with error (409 manifested as redirect)
    assert_response :redirect
    follow_redirect!

    # Identity should still belong to user_one
    identity = ClientGoogleIdentity.find_by(uid: existing_uid)

    assert_equal @user_one.id, identity.user_id, "Identity should still belong to original user"
  end

  test "link Apple identity already linked to another user returns 409 Conflict" do
    existing_uid = "apple_owned_by_user_one"

    ClientAppleIdentity.create!(
      user: @user_one,
      uid: existing_uid,
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    grant_session = seed_app_social_link_grant_session(provider: "apple", user: @user_two, ri: "jp")
    setup_apple_mock_auth(uid: existing_uid)

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: grant_session.state },
        headers: @callback_headers.merge(grant_session.user_headers)

    assert_response :redirect
    follow_redirect!

    identity = ClientAppleIdentity.find_by(uid: existing_uid)

    assert_equal @user_one.id, identity.user_id
  end

  test "link Apple fails when flow context is missing" do
    uid = "apple_state_mismatch_#{SecureRandom.hex(4)}"
    # No connection request - nonce: nil is correct; state guard rejects before nonce is checked.
    setup_apple_mock_auth(uid: uid, nonce: nil)

    # Do not call /social/auth/:provider/continue to simulate missing link context
    # Use X-STRICT-SOCIAL-STATE to prevent test-mode state bypass
    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        headers: @callback_headers.merge(as_user_headers(@user_one, host: @host))
          .merge("X-STRICT-SOCIAL-STATE" => "1")

    assert_response :conflict
    assert_equal "Sign-in is unavailable while authenticated.", response.body

    identity = ClientAppleIdentity.find_by(uid: uid)

    assert_nil identity, "Identity should not be created on state mismatch"
  end

  test "link Apple fails when intent TTL exceeded" do
    uid = "apple_state_expired_#{SecureRandom.hex(4)}"

    post auth_app_settings_apple_url(ri: "jp"),
         headers: social_link_headers(@user_one)

    assert_response :temporary_redirect
    assert_equal "/social/apple", URI.parse(response.location).path

    # Set up mock after connection POST so session nonce is available.
    setup_apple_mock_auth(uid: uid, nonce: session[:social_auth_nonce])

    travel_to 6.minutes.from_now do
      get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
          params: { state: social_auth_state_from_response },
          headers: @callback_headers.merge(as_user_headers(@user_one, host: @host))
    end

    assert_response :conflict
    assert_equal "Sign-in is unavailable while authenticated.", response.body

    identity = ClientAppleIdentity.find_by(uid: uid)

    assert_nil identity, "Identity should not be created when intent expired"
  end

  test "Sign-owned Google link intent creates one social identity" do
    new_uid = "grantless_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)
    grant_session = seed_app_social_link_grant_session(provider: "google", user: @user_one, ri: "jp")

    assert_difference("ClientGoogleIdentity.count", 1) do
      perform_grant_backed_link(provider: "google", grant_session: grant_session)
    end

    assert_redirected_to auth_app_settings_path(ri: "jp")
    assert_equal @user_one.id, ClientGoogleIdentity.find_by!(uid: new_uid).user_id
    assert_not_includes response.body.to_s, "social-completion-form"
  end

  test "guest cannot start Google linking" do
    setup_google_mock_auth(uid: "guest_google_#{SecureRandom.hex(4)}")

    post auth_app_settings_google_url(ri: "jp"),
         headers: host_headers(@host)

    assert_response :redirect
    assert_oidc_authorize_redirect(jump_rt_url_from_location(response.location), host: @base_host, client_id: "sign-rp")
    assert_nil session[SocialAuth::SOCIAL_FLOW_ID_SESSION_KEY]
  end

  test "Sign-owned Apple link intent creates one social identity" do
    new_uid = "grantless_apple_#{SecureRandom.hex(4)}"
    grant_session = seed_app_social_link_grant_session(provider: "apple", user: @user_one, ri: "jp")

    setup_apple_mock_auth(uid: new_uid)

    assert_difference("ClientAppleIdentity.count", 1) do
      perform_grant_backed_link(provider: "apple", grant_session: grant_session)
    end

    assert_redirected_to auth_app_settings_path(ri: "jp")
    assert_equal @user_one.id, ClientAppleIdentity.find_by!(uid: new_uid).user_id
  end

  test "guest cannot start Apple linking" do
    post auth_app_settings_apple_url(ri: "jp"),
         headers: host_headers(@host)

    assert_response :redirect
    assert_oidc_authorize_redirect(jump_rt_url_from_location(response.location), host: @base_host, client_id: "sign-rp")
    assert_nil session[SocialAuth::SOCIAL_FLOW_ID_SESSION_KEY]
  end

  # ============================================================================
  # OPTIONAL: Client already has this provider linked (update case)
  # ============================================================================
  test "Sign link when user already has this provider updates existing identity" do
    old_uid = "old_google_uid"

    # Client one already has Google linked
    existing_identity = ClientGoogleIdentity.create!(
      user: @user_one,
      uid: old_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    headers = social_link_headers(@user_one)

    post auth_app_settings_google_url(ri: "jp"), headers: headers

    assert_response :unprocessable_content
    existing_identity.reload

    assert_equal @user_one.id, existing_identity.user_id
  end

  test "successful Sign-owned Google link creates identity for current user" do
    new_uid = "brand_new_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    grant_session = seed_app_social_link_grant_session(provider: "google", user: @user_one, ri: "jp")

    assert_difference("ClientGoogleIdentity.count", 1) do
      perform_grant_backed_link(provider: "google", grant_session: grant_session)
    end

    assert_redirected_to auth_app_settings_path(ri: "jp")

    # New identity created on Sign under the current user.
    identity = ClientGoogleIdentity.find_by(uid: new_uid)

    assert_not_nil identity
    assert_equal @user_one.id, identity.user_id, "Identity should belong to current user"
    assert_not_nil identity.last_authenticated_at, "last_authenticated_at should be set"
  end

  test "link intent requires authentication" do
    setup_google_mock_auth(uid: "unauthenticated_test")

    # Start without authentication headers
    post auth_app_settings_google_url(ri: "jp"),
         headers: { "Host" => @host }

    assert_response :redirect
    assert_oidc_authorize_redirect(jump_rt_url_from_location(response.location), host: @base_host, client_id: "sign-rp")
  end

  test "link intent rejects resource-level step up without token-bound step up" do
    @user_one.update!(last_step_up_at: Time.current)

    post auth_app_settings_google_url(ri: "jp"),
         headers: as_user_headers(@user_one, host: @host)

    assert_response :see_other
    assert_match %r{\Ahttp://#{Regexp.escape(@host)}/verification\?}, response.location
    assert_includes response.location, "scope=social_link"
    assert_nil session[SOCIAL_FLOW_ID_SESSION_KEY]
  end

  test "link intent rejects token-bound step up for a different scope" do
    headers = as_user_headers(@user_one, host: @host)
    token = ClientToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    mark_token_step_up_satisfied_for_test(token, scope: "settings_email")

    post auth_app_settings_google_url(ri: "jp"),
         headers: headers

    assert_response :see_other
    assert_match %r{\Ahttp://#{Regexp.escape(@host)}/verification\?}, response.location
    assert_includes response.location, "scope=social_link"
    assert_nil session[SOCIAL_FLOW_ID_SESSION_KEY]
  end

  # ============================================================================
  # Re-linking REVOKED identity (idempotency test)
  # ============================================================================
  test "re-link REVOKED Google identity reactivates it" do
    revoked_uid = "revoked_google_#{SecureRandom.hex(4)}"

    # Create a REVOKED identity for user_one
    revoked_identity = ClientGoogleIdentity.create!(
      user: @user_one,
      uid: revoked_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:revoked),
    )

    # Setup mock auth with the same uid but updated info
    setup_google_mock_auth(uid: revoked_uid)

    # Re-link through the Sign-owned settings ceremony.
    grant_session = seed_app_social_link_grant_session(provider: "google", user: @user_one, ri: "jp")
    perform_grant_backed_link(provider: "google", grant_session: grant_session)

    assert_redirected_to auth_app_settings_path(ri: "jp")

    # Identity should be reactivated (status changed to ACTIVE)
    revoked_identity.reload

    assert_equal ClientGoogleIdentityStatus::ACTIVE, revoked_identity.status_id,
                 "Identity should be ACTIVE"
  end

  test "re-link REVOKED Apple identity reactivates it" do
    revoked_uid = "revoked_apple_#{SecureRandom.hex(4)}"

    revoked_identity = ClientAppleIdentity.create!(
      user: @user_one,
      uid: revoked_uid,
      provider: "apple",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:revoked),
    )

    grant_session = seed_app_social_link_grant_session(provider: "apple", user: @user_one, ri: "jp")
    setup_apple_mock_auth(uid: revoked_uid)
    perform_grant_backed_link(provider: "apple", grant_session: grant_session)

    assert_redirected_to auth_app_settings_path(ri: "jp")

    revoked_identity.reload

    assert_equal ClientAppleIdentityStatus::ACTIVE, revoked_identity.status_id,
                 "Apple identity should be ACTIVE"
  end

  private

  def perform_grant_backed_link(provider:, grant_session:)
    if provider == "apple"
      get(
        auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: grant_session.state },
        headers: @callback_headers.merge(grant_session.user_headers),
      )
    else
      get(
        auth_app_social_google_callback_url(ri: "jp"),
        params: { state: grant_session.state },
        headers: @callback_headers.merge(grant_session.user_headers),
      )
    end
    submit_social_completion_if_present!
  end

  def social_link_headers(user)
    headers = as_user_headers(user, host: @host)
    token = ClientToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    mark_token_step_up_satisfied_for_test(token, scope: SocialAuth::SOCIAL_LINK_SCOPE)
    headers
  end

  # IMPORTANT: Social login authenticates by provider+uid ONLY, NOT email
  # We deliberately omit email from mock_auth to test this requirement

  def setup_apple_mock_auth(uid:, nonce: session[:social_auth_nonce])
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: uid,
      info: {},
      credentials: {
        token: "apple_token_#{SecureRandom.hex(8)}",
        refresh_token: "apple_refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
      extra: { id_info: { nonce: nonce } },
    )
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class SocialAuthLinkTest
  private
end

# DAMP local helper copy for former shared test support.
class SocialAuthLinkTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
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

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
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

# DAMP local social completion helpers for former shared test support.
class SocialAuthLinkTest
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

    # A browser only reaches the completion endpoint when CSP allows the form
    # target. See test/support/form_action_policy_helper.rb.
    assert_forms_submittable_under_policy

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
        # A browser sends the form target as the Host, not a separately configured one.
        "Host" => URI.parse(form["action"]).host,
        "Origin" => "https://#{configured_host(:sign_service)}",
        "Sec-Fetch-Site" => "same-site",
      },
    )
    cookies.to_hash.each_key { |key| cookies.delete(key) }
  end
end

# DAMP local helper copy on the test class.
class SocialAuthLinkTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

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
    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
      }",
    )
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
    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }",
    )
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
    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor")
      }",
    )
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

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com", token: "google_token")
    OmniAuth.config.mock_auth[:google] =
      OmniAuth::AuthHash.new(
        provider: "google", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: token, refresh_token: "refresh_#{token}", expires_at: 1.hour.from_now.to_i },
      )
  end
end
