# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/invalid-browser-credential-recovery.md, Auth. A refused auth browser credential is detached
# with deletions that match the issued cookie's identity, and the request continues anonymous: a
# public HTML page renders, a protected HTML page takes the ordinary sign-in path, and JSON keeps its
# authentication failure contract. Policy states and system failures are not credential refusals.
class AuthInvalidCookieRecoveryTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators

  ACCESS = OidcRpBrowserCredentialContract::ACCESS_COOKIE
  REFRESH = AuthenticationBase::REFRESH_COOKIE_KEY
  DBSC = AuthenticationBase::DBSC_COOKIE_KEY
  AUTH_COOKIES = [ACCESS, REFRESH, DBSC].freeze

  SURFACES = {
    app: { host_env: "PUBLIC_BASE_SERVICE_URL" },
    com: { host_env: "PUBLIC_BASE_CORPORATE_URL" },
    org: { host_env: "PUBLIC_BASE_STAFF_URL" },
  }.freeze

  setup { https! }

  # --- Access cookie: every surface, public and protected HTML -------------------------------------

  SURFACES.each do |surface, config|
    test "#{surface}: a malformed access cookie is detached and a public page renders anonymous" do
      host! ENV.fetch(config[:host_env])
      cookies[ACCESS] = "malformed"

      get "/?ri=jp"

      assert_response :success
      assert_cookie_deleted(ACCESS)
      # Rails emits a deletion only for a cookie the request carried; absent ones need none.
      [REFRESH, DBSC].each { |name| assert_no_set_cookie(name) }

      get "/?ri=jp"

      assert_response :success
      assert_no_set_cookie(ACCESS)
    end

    # An anonymous HTML Dashboard request is sent to the passive sign-in page; a refused credential
    # takes that same path after it is detached.
    test "#{surface}: a malformed access cookie on a protected page takes the same sign-in redirect as no cookie" do
      host! ENV.fetch(config[:host_env])
      get "/dashboard?ri=jp"

      assert_response :redirect
      anonymous_location = response.location

      assert_equal "/sign", URI.parse(anonymous_location).path

      cookies[ACCESS] = "malformed"
      get "/dashboard?ri=jp"

      assert_response :redirect
      assert_equal anonymous_location, response.location
      assert_cookie_deleted(ACCESS)
    end

    test "#{surface}: a HEAD with a malformed access cookie on a protected page detaches it on the redirect" do
      host! ENV.fetch(config[:host_env])
      cookies[ACCESS] = "malformed"
      head "/dashboard?ri=jp"

      assert_response :redirect
      assert_equal "/sign", URI.parse(response.location).path
      assert_cookie_deleted(ACCESS)
    end

    test "#{surface}: a protected page redirect without an access cookie deletes no credential cookie" do
      host! ENV.fetch(config[:host_env])
      get "/dashboard?ri=jp"

      assert_response :redirect
      AUTH_COOKIES.each { |name| assert_no_set_cookie(name) }
      assert_no_set_cookie(ACCESS)
    end

    test "#{surface}: an access cookie naming a session that does not exist is detached" do
      host! ENV.fetch(config[:host_env])
      resource = surface_resource(surface)
      cookies[ACCESS] =
        begin
          rc8_actor = resource
          rc8_type = { Client => "client", Visitor => "visitor", Operator => "operator" }.fetch(rc8_actor.class)
          rc8_realm = { "client" => "app", "visitor" => "com", "operator" => "org" }.fetch(rc8_type)
          rc8_root_model = {
            "client" => ClientToken,
            "visitor" => VisitorToken,
            "operator" => OperatorToken,
          }.fetch(rc8_type)
          rc8_root = rc8_root_model.find_by(public_id: "missing#{SecureRandom.hex(6)}") || surface_token(
            rc8_realm.to_sym,
            rc8_actor,
          )
          rc8_registered = OidcClientRegistry.find!(
            {
              "app" => "base-app-ww",
              "com" => "base-com-ww",
              "org" => "base-org-ww",
            }.fetch(rc8_realm),
          )
          rc8_rp_model = {
            "client" => ClientRpSession,
            "visitor" => VisitorRpSession,
            "operator" => OperatorRpSession,
          }.fetch(rc8_type)
          rc8_fk = {
            "client" => :client_token_id,
            "visitor" => :visitor_token_id,
            "operator" => :operator_token_id,
          }.fetch(rc8_type)
          rc8_rp = rc8_rp_model.create!(
            rc8_fk => rc8_root.id, :device_session_id => rc8_root.device_session_id,
            :oidc_client_id => rc8_registered.client_id, :oidc_scope => "openid profile",
            :oidc_jti => SecureRandom.uuid, :oidc_auth_time => Time.current,
            :refresh_token_expires_at => 10.minutes.from_now,
          )
          AuthenticationTokenService.encode(
            rc8_actor, host: host, resource_type: rc8_type,
                       session_public_id: rc8_root.public_id, base_session_public_id: rc8_root.public_id,
                       oidc_sid: "missing#{SecureRandom.hex(6)}", oidc_jti: rc8_rp.oidc_jti,
                       expires_at: 5.minutes.from_now, scopes: %w(openid profile),
                       issuer: OidcIssuer.for_resource_type(rc8_type), audiences: [rc8_registered.aud],
                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rc8_registered),
                       subject: OidcSubject.for(
                         rc8_actor,
                         resource_type: rc8_type,
                       ), client_id: rc8_registered.client_id,
          )
        end

      get "/?ri=jp"

      assert_response :success
      assert_cookie_deleted(ACCESS)
    end

    test "#{surface}: an access cookie for a revoked session is detached" do
      host! ENV.fetch(config[:host_env])
      resource = surface_resource(surface)
      token = surface_token(surface, resource)
      cookies[ACCESS] =
        begin
          rc7_actor = resource
          rc7_type = { Client => "client", Visitor => "visitor", Operator => "operator" }.fetch(rc7_actor.class)
          rc7_realm = { "client" => "app", "visitor" => "com", "operator" => "org" }.fetch(rc7_type)
          rc7_root_model = {
            "client" => ClientToken,
            "visitor" => VisitorToken,
            "operator" => OperatorToken,
          }.fetch(rc7_type)
          rc7_root = rc7_root_model.find_by(public_id: token.public_id) || surface_token(
            rc7_realm.to_sym,
            rc7_actor,
          )
          rc7_registered = OidcClientRegistry.find!(
            {
              "app" => "base-app-ww",
              "com" => "base-com-ww",
              "org" => "base-org-ww",
            }.fetch(rc7_realm),
          )
          rc7_rp_model = {
            "client" => ClientRpSession,
            "visitor" => VisitorRpSession,
            "operator" => OperatorRpSession,
          }.fetch(rc7_type)
          rc7_fk = {
            "client" => :client_token_id,
            "visitor" => :visitor_token_id,
            "operator" => :operator_token_id,
          }.fetch(rc7_type)
          rc7_rp = rc7_rp_model.create!(
            rc7_fk => rc7_root.id, :device_session_id => rc7_root.device_session_id,
            :oidc_client_id => rc7_registered.client_id, :oidc_scope => "openid profile",
            :oidc_jti => SecureRandom.uuid, :oidc_auth_time => Time.current,
            :refresh_token_expires_at => 10.minutes.from_now,
          )
          AuthenticationTokenService.encode(
            rc7_actor, host: host, resource_type: rc7_type,
                       session_public_id: rc7_root.public_id, base_session_public_id: rc7_root.public_id,
                       oidc_sid: rc7_rp.public_id, oidc_jti: rc7_rp.oidc_jti,
                       expires_at: 5.minutes.from_now, scopes: %w(openid profile),
                       issuer: OidcIssuer.for_resource_type(rc7_type), audiences: [rc7_registered.aud],
                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rc7_registered),
                       subject: OidcSubject.for(
                         rc7_actor,
                         resource_type: rc7_type,
                       ), client_id: rc7_registered.client_id,
          )
        end
      token.update_columns(discard_at: 1.second.ago)

      get "/?ri=jp"

      assert_response :success
      assert_cookie_deleted(ACCESS)
    end

    test "#{surface}: a valid access cookie is kept" do
      host! ENV.fetch(config[:host_env])
      resource = surface_resource(surface)
      token = surface_token(surface, resource)
      cookies[ACCESS] =
        begin
          rc6_actor = resource
          rc6_type = { Client => "client", Visitor => "visitor", Operator => "operator" }.fetch(rc6_actor.class)
          rc6_realm = { "client" => "app", "visitor" => "com", "operator" => "org" }.fetch(rc6_type)
          rc6_root_model = {
            "client" => ClientToken,
            "visitor" => VisitorToken,
            "operator" => OperatorToken,
          }.fetch(rc6_type)
          rc6_root = rc6_root_model.find_by(public_id: token.public_id) || surface_token(
            rc6_realm.to_sym,
            rc6_actor,
          )
          rc6_registered = OidcClientRegistry.find!(
            {
              "app" => "base-app-ww",
              "com" => "base-com-ww",
              "org" => "base-org-ww",
            }.fetch(rc6_realm),
          )
          rc6_rp_model = {
            "client" => ClientRpSession,
            "visitor" => VisitorRpSession,
            "operator" => OperatorRpSession,
          }.fetch(rc6_type)
          rc6_fk = {
            "client" => :client_token_id,
            "visitor" => :visitor_token_id,
            "operator" => :operator_token_id,
          }.fetch(rc6_type)
          rc6_rp = rc6_rp_model.create!(
            rc6_fk => rc6_root.id, :device_session_id => rc6_root.device_session_id,
            :oidc_client_id => rc6_registered.client_id, :oidc_scope => "openid profile",
            :oidc_jti => SecureRandom.uuid, :oidc_auth_time => Time.current,
            :refresh_token_expires_at => 10.minutes.from_now,
          )
          AuthenticationTokenService.encode(
            rc6_actor, host: host, resource_type: rc6_type,
                       session_public_id: rc6_root.public_id, base_session_public_id: rc6_root.public_id,
                       oidc_sid: rc6_rp.public_id, oidc_jti: rc6_rp.oidc_jti,
                       expires_at: 5.minutes.from_now, scopes: %w(openid profile),
                       issuer: OidcIssuer.for_resource_type(rc6_type), audiences: [rc6_registered.aud],
                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rc6_registered),
                       subject: OidcSubject.for(
                         rc6_actor,
                         resource_type: rc6_type,
                       ), client_id: rc6_registered.client_id,
          )
        end

      # Home 404s for a member, so the kept credential is observed on the authenticated Dashboard.
      get "/dashboard?ri=jp"

      assert_operator response.status, :<, 400
      assert_no_set_cookie(ACCESS)
    end
  end

  # --- Access cookie EP/BVA (app) -----------------------------------------------------------------

  {
    "a lone separator" => ".",
    "a missing component" => "header.payload",
    "an extra component" => "a.b.c.d",
    "invalid base64url" => "!!!.@@@.###",
    "a zero-length decoded segment" => "..",
    "a percent-encoded NUL" => "%00",
    "invalid UTF-8 bytes" => "%FF%FE.%C3%28",
    "an oversized value" => "a" * 4000,
    "an unsigned token with an unknown algorithm" =>
      "#{Base64.urlsafe_encode64('{"alg":"none","typ":"JWT"}', padding: false)}." \
      "#{Base64.urlsafe_encode64('{"sub":"x"}', padding: false)}.",
  }.each do |label, value|
    test "app: an access cookie with #{label} is detached and the page renders anonymous" do
      host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      cookies[ACCESS] = value

      get "/?ri=jp"

      assert_response :success
      assert_cookie_deleted(ACCESS)
    end
  end

  # Rack strips surrounding whitespace from a cookie value, so whitespace reaches the application as
  # the empty value and falls in the same partition.
  { "empty" => "", "whitespace-only" => " " }.each do |label, value|
    test "app: an #{label} access cookie is treated as absent and nothing is deleted" do
      host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      cookies[ACCESS] = value

      get "/?ri=jp"

      assert_response :success
      assert_no_set_cookie(ACCESS)
    end
  end

  test "app: a truncated valid access token is detached" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    resource = clients(:one)
    token = ClientToken.create!(user: resource)
    cookies[ACCESS] = begin
      rc5_actor = resource
      rc5_type = { Client => "client", Visitor => "visitor", Operator => "operator" }.fetch(rc5_actor.class)
      rc5_realm = { "client" => "app", "visitor" => "com", "operator" => "org" }.fetch(rc5_type)
      rc5_root_model = {
        "client" => ClientToken,
        "visitor" => VisitorToken,
        "operator" => OperatorToken,
      }.fetch(rc5_type)
      rc5_root = rc5_root_model.find_by(public_id: token.public_id) || surface_token(rc5_realm.to_sym, rc5_actor)
      rc5_registered = OidcClientRegistry.find!(
        {
          "app" => "base-app-ww",
          "com" => "base-com-ww",
          "org" => "base-org-ww",
        }.fetch(rc5_realm),
      )
      rc5_rp_model = {
        "client" => ClientRpSession,
        "visitor" => VisitorRpSession,
        "operator" => OperatorRpSession,
      }.fetch(rc5_type)
      rc5_fk = {
        "client" => :client_token_id,
        "visitor" => :visitor_token_id,
        "operator" => :operator_token_id,
      }.fetch(rc5_type)
      rc5_rp = rc5_rp_model.create!(
        rc5_fk => rc5_root.id, :device_session_id => rc5_root.device_session_id,
        :oidc_client_id => rc5_registered.client_id, :oidc_scope => "openid profile",
        :oidc_jti => SecureRandom.uuid, :oidc_auth_time => Time.current,
        :refresh_token_expires_at => 10.minutes.from_now,
      )
      AuthenticationTokenService.encode(
        rc5_actor, host: host, resource_type: rc5_type,
                   session_public_id: rc5_root.public_id, base_session_public_id: rc5_root.public_id,
                   oidc_sid: rc5_rp.public_id, oidc_jti: rc5_rp.oidc_jti,
                   expires_at: 5.minutes.from_now, scopes: %w(openid profile),
                   issuer: OidcIssuer.for_resource_type(rc5_type), audiences: [rc5_registered.aud],
                   jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rc5_registered),
                   subject: OidcSubject.for(rc5_actor, resource_type: rc5_type), client_id: rc5_registered.client_id,
      )
    end[0...-8]

    get "/?ri=jp"

    assert_response :success
    assert_cookie_deleted(ACCESS)
  end

  # JWT expiry is checked as `exp <= now - leeway`, so the last accepted instant is one second before
  # `exp + leeway`.
  [
    ["one second before the expiry boundary", -1, false],
    ["exactly at the expiry boundary", 0, true],
    ["one second after the expiry boundary", 1, true],
  ].each do |label, offset, detached|
    test "app: an access cookie #{label} is #{detached ? "detached" : "kept"}" do
      host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      resource = clients(:one)
      token = ClientToken.create!(user: resource)
      freeze_time
      expires_at = 5.minutes.from_now
      cookies[ACCESS] =
        begin
          rc4_actor = resource
          rc4_type = { Client => "client", Visitor => "visitor", Operator => "operator" }.fetch(rc4_actor.class)
          rc4_realm = { "client" => "app", "visitor" => "com", "operator" => "org" }.fetch(rc4_type)
          rc4_root_model = {
            "client" => ClientToken,
            "visitor" => VisitorToken,
            "operator" => OperatorToken,
          }.fetch(rc4_type)
          rc4_root = rc4_root_model.find_by(public_id: token.public_id) || surface_token(
            rc4_realm.to_sym,
            rc4_actor,
          )
          rc4_registered = OidcClientRegistry.find!(
            {
              "app" => "base-app-ww",
              "com" => "base-com-ww",
              "org" => "base-org-ww",
            }.fetch(rc4_realm),
          )
          rc4_rp_model = {
            "client" => ClientRpSession,
            "visitor" => VisitorRpSession,
            "operator" => OperatorRpSession,
          }.fetch(rc4_type)
          rc4_fk = {
            "client" => :client_token_id,
            "visitor" => :visitor_token_id,
            "operator" => :operator_token_id,
          }.fetch(rc4_type)
          rc4_rp = rc4_rp_model.create!(
            rc4_fk => rc4_root.id, :device_session_id => rc4_root.device_session_id,
            :oidc_client_id => rc4_registered.client_id, :oidc_scope => "openid profile",
            :oidc_jti => SecureRandom.uuid, :oidc_auth_time => Time.current,
            :refresh_token_expires_at => 10.minutes.from_now,
          )
          AuthenticationTokenService.encode(
            rc4_actor, host: host, resource_type: rc4_type,
                       session_public_id: rc4_root.public_id, base_session_public_id: rc4_root.public_id,
                       oidc_sid: rc4_rp.public_id, oidc_jti: rc4_rp.oidc_jti,
                       expires_at: expires_at, scopes: %w(openid profile),
                       issuer: OidcIssuer.for_resource_type(rc4_type), audiences: [rc4_registered.aud],
                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rc4_registered),
                       subject: OidcSubject.for(
                         rc4_actor,
                         resource_type: rc4_type,
                       ), client_id: rc4_registered.client_id,
          )
        end
      travel_to(expires_at + AuthenticationJwtConfiguration.leeway_seconds.seconds + offset.seconds)

      # A kept credential reaches Dashboard; a detached one falls back to anonymous Home.
      get(detached ? "/?ri=jp" : "/dashboard?ri=jp")

      assert_operator response.status, :<, 400
      detached ? assert_cookie_deleted(ACCESS) : assert_no_set_cookie(ACCESS)
    end
  end

  test "app: an access cookie for a session idle past the window is detached as a lifecycle end" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    resource = clients(:one)
    token = ClientToken.create!(user: resource)
    cookies[ACCESS] =
      begin
        rc3_actor = resource
        rc3_type = { Client => "client", Visitor => "visitor", Operator => "operator" }.fetch(rc3_actor.class)
        rc3_realm = { "client" => "app", "visitor" => "com", "operator" => "org" }.fetch(rc3_type)
        rc3_root_model = {
          "client" => ClientToken,
          "visitor" => VisitorToken,
          "operator" => OperatorToken,
        }.fetch(rc3_type)
        rc3_root = rc3_root_model.find_by(public_id: token.public_id) || surface_token(rc3_realm.to_sym, rc3_actor)
        rc3_registered = OidcClientRegistry.find!(
          {
            "app" => "base-app-ww",
            "com" => "base-com-ww",
            "org" => "base-org-ww",
          }.fetch(rc3_realm),
        )
        rc3_rp_model = {
          "client" => ClientRpSession,
          "visitor" => VisitorRpSession,
          "operator" => OperatorRpSession,
        }.fetch(rc3_type)
        rc3_fk = {
          "client" => :client_token_id,
          "visitor" => :visitor_token_id,
          "operator" => :operator_token_id,
        }.fetch(rc3_type)
        rc3_rp = rc3_rp_model.create!(
          rc3_fk => rc3_root.id, :device_session_id => rc3_root.device_session_id,
          :oidc_client_id => rc3_registered.client_id, :oidc_scope => "openid profile",
          :oidc_jti => SecureRandom.uuid, :oidc_auth_time => Time.current,
          :refresh_token_expires_at => 10.minutes.from_now,
        )
        AuthenticationTokenService.encode(
          rc3_actor, host: host, resource_type: rc3_type,
                     session_public_id: rc3_root.public_id, base_session_public_id: rc3_root.public_id,
                     oidc_sid: rc3_rp.public_id, oidc_jti: rc3_rp.oidc_jti,
                     expires_at: 5.minutes.from_now, scopes: %w(openid profile),
                     issuer: OidcIssuer.for_resource_type(rc3_type), audiences: [rc3_registered.aud],
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rc3_registered),
                     subject: OidcSubject.for(rc3_actor, resource_type: rc3_type), client_id: rc3_registered.client_id,
        )
      end
    token.update_columns(last_used_at: SecurityTokenLifetimes::CLIENT_IDLE_TTL.ago - 1.minute)

    logs = capture_logs { get("/?ri=jp") }

    assert_response :success
    assert_cookie_deleted(ACCESS)
    assert_not_predicate rc3_rp.reload, :active?
    assert_predicate token.reload, :currently_usable?
    assert_empty auth_rejection_events(logs)
  end

  test "app: a JSON request with a malformed access cookie keeps the existing 401 contract" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = "malformed"

    get "/edge/v0/token/check", headers: { "Accept" => "application/json" }, as: :json

    assert_response :unauthorized
    assert_equal I18n.t("auth.session_expired"), response.body
    assert_no_set_cookie(ACCESS)
  end

  # --- Policy states are not credential refusals ---------------------------------------------------

  test "app: a withdrawn account's valid access cookie is not detached as an invalid credential" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    token = ClientToken.create!(user: user)
    cookies[ACCESS] =
      begin
        rc2_actor = user
        rc2_type = { Client => "client", Visitor => "visitor", Operator => "operator" }.fetch(rc2_actor.class)
        rc2_realm = { "client" => "app", "visitor" => "com", "operator" => "org" }.fetch(rc2_type)
        rc2_root_model = {
          "client" => ClientToken,
          "visitor" => VisitorToken,
          "operator" => OperatorToken,
        }.fetch(rc2_type)
        rc2_root = rc2_root_model.find_by(public_id: token.public_id) || surface_token(rc2_realm.to_sym, rc2_actor)
        rc2_registered = OidcClientRegistry.find!(
          {
            "app" => "base-app-ww",
            "com" => "base-com-ww",
            "org" => "base-org-ww",
          }.fetch(rc2_realm),
        )
        rc2_rp_model = {
          "client" => ClientRpSession,
          "visitor" => VisitorRpSession,
          "operator" => OperatorRpSession,
        }.fetch(rc2_type)
        rc2_fk = {
          "client" => :client_token_id,
          "visitor" => :visitor_token_id,
          "operator" => :operator_token_id,
        }.fetch(rc2_type)
        rc2_rp = rc2_rp_model.create!(
          rc2_fk => rc2_root.id, :device_session_id => rc2_root.device_session_id,
          :oidc_client_id => rc2_registered.client_id, :oidc_scope => "openid profile",
          :oidc_jti => SecureRandom.uuid, :oidc_auth_time => Time.current,
          :refresh_token_expires_at => 10.minutes.from_now,
        )
        AuthenticationTokenService.encode(
          rc2_actor, host: host, resource_type: rc2_type,
                     session_public_id: rc2_root.public_id, base_session_public_id: rc2_root.public_id,
                     oidc_sid: rc2_rp.public_id, oidc_jti: rc2_rp.oidc_jti,
                     expires_at: 5.minutes.from_now, scopes: %w(openid profile),
                     issuer: OidcIssuer.for_resource_type(rc2_type), audiences: [rc2_registered.aud],
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rc2_registered),
                     subject: OidcSubject.for(rc2_actor, resource_type: rc2_type), client_id: rc2_registered.client_id,
        )
      end

    user.update!(
      withdrawal_started_at: 1.day.ago, deactivated_at: Time.current, discard_at: Time.current,
      purge_eligible_at: 31.days.from_now,
    )

    logs = capture_logs { get("/dashboard?ri=jp") }

    assert_not_predicate response, :successful?
    assert_no_set_cookie(ACCESS)
    assert_empty auth_rejection_events(logs)
  end

  # --- Surface separation ------------------------------------------------------------------------

  test "app recovery neither writes a Domain cookie nor disturbs a valid com session" do
    com_host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    visitor = surface_resource(:com)
    com_token = surface_token(:com, visitor)
    com_access =
      begin
        rc1_actor = visitor
        rc1_type = { Client => "client", Visitor => "visitor", Operator => "operator" }.fetch(rc1_actor.class)
        rc1_realm = { "client" => "app", "visitor" => "com", "operator" => "org" }.fetch(rc1_type)
        rc1_root_model = {
          "client" => ClientToken,
          "visitor" => VisitorToken,
          "operator" => OperatorToken,
        }.fetch(rc1_type)
        rc1_root = rc1_root_model.find_by(public_id: com_token.public_id) || surface_token(
          rc1_realm.to_sym,
          rc1_actor,
        )
        rc1_registered = OidcClientRegistry.find!(
          {
            "app" => "base-app-ww",
            "com" => "base-com-ww",
            "org" => "base-org-ww",
          }.fetch(rc1_realm),
        )
        rc1_rp_model = {
          "client" => ClientRpSession,
          "visitor" => VisitorRpSession,
          "operator" => OperatorRpSession,
        }.fetch(rc1_type)
        rc1_fk = {
          "client" => :client_token_id,
          "visitor" => :visitor_token_id,
          "operator" => :operator_token_id,
        }.fetch(rc1_type)
        rc1_rp = rc1_rp_model.create!(
          rc1_fk => rc1_root.id, :device_session_id => rc1_root.device_session_id,
          :oidc_client_id => rc1_registered.client_id, :oidc_scope => "openid profile",
          :oidc_jti => SecureRandom.uuid, :oidc_auth_time => Time.current,
          :refresh_token_expires_at => 10.minutes.from_now,
        )
        AuthenticationTokenService.encode(
          rc1_actor, host: com_host, resource_type: rc1_type,
                     session_public_id: rc1_root.public_id, base_session_public_id: rc1_root.public_id,
                     oidc_sid: rc1_rp.public_id, oidc_jti: rc1_rp.oidc_jti,
                     expires_at: 5.minutes.from_now, scopes: %w(openid profile),
                     issuer: OidcIssuer.for_resource_type(rc1_type), audiences: [rc1_registered.aud],
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rc1_registered),
                     subject: OidcSubject.for(rc1_actor, resource_type: rc1_type), client_id: rc1_registered.client_id,
        )
      end

    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get "/?ri=jp", headers: { "Cookie" => "#{ACCESS}=malformed" }

    assert_cookie_deleted(ACCESS)
    assert(set_cookie_entries(ACCESS).none? { |entry| entry.key?(:domain) }, "the deletion must stay host-only")

    host! com_host
    get "/dashboard?ri=jp", headers: { "Cookie" => "#{ACCESS}=#{com_access}" }

    assert_operator response.status, :<, 400
    assert_no_set_cookie(ACCESS)
    assert_predicate com_token.reload.discard_at, :future?
  end

  # --- Refresh and DBSC cookies (JSON refresh endpoint) ------------------------------------------

  test "the issued auth cookies and their deletions share name, path, host-only scope, Secure, and SameSite" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = ClientToken.create!(user: clients(:one))
    refresh_plain = token.rotate_refresh_token!

    post_refresh(refresh_plain)

    assert_response :success
    issued = {
      AuthenticationBase::ACCESS_COOKIE_KEY => assert_cookie_issued(AuthenticationBase::ACCESS_COOKIE_KEY),
      REFRESH => assert_cookie_issued(REFRESH),
    }

    forged = "#{token.public_id}.#{SecureRandom.urlsafe_base64(32)}"
    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           "Cookie" => "#{AuthenticationBase::ACCESS_COOKIE_KEY}=" \
                       "#{issued[AuthenticationBase::ACCESS_COOKIE_KEY][:value]}; " \
                       "#{REFRESH}=#{Rack::Utils.escape(forged)}",
         },
         as: :json

    assert_response :unauthorized
    issued.each { |name, entry| assert_cookie_deleted(name, issued: entry) }
  end

  {
    "malformed" => ->(_token) { "garbage" },
    "a missing verifier" => ->(token) { "#{token.public_id}." },
    "a nonexistent public_id" => ->(_token) { "missing#{SecureRandom.hex(6)}.#{SecureRandom.urlsafe_base64(32)}" },
    "a correct public_id and an incorrect verifier" =>
      ->(token) { "#{token.public_id}.#{SecureRandom.urlsafe_base64(32)}" },
  }.each do |label, forge|
    test "refresh: #{label} is refused with the shared JSON body and every auth cookie is deleted" do
      host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      token = ClientToken.create!(user: clients(:one))
      token.rotate_refresh_token!

      post_refresh(forge.call(token))

      assert_invalid_refresh_response
      assert_cookie_deleted(REFRESH)
      assert_predicate token.reload.discard_at, :future?, "a forged credential must not revoke the real session"
    end
  end

  test "refresh: a credential at its discard boundary is refused as a lifecycle end" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = ClientToken.create!(user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.update_columns(discard_at: token.class.database_now)

    logs = capture_logs { post_refresh(refresh_plain) }

    assert_invalid_refresh_response
    assert_cookie_deleted(REFRESH)
    assert_equal %w(inactive_token lifecycle), auth_rejection_events(logs).sole.values_at("reason", "category")
  end

  # BVA exception: the rotation lock compares discard_at with the database clock, which travel_to
  # cannot freeze, so "just before" is the nearest value that stays ahead of real elapsed time.
  test "refresh: a credential shortly before its discard boundary refreshes" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = ClientToken.create!(user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.update_columns(discard_at: 1.minute.from_now)

    post_refresh(refresh_plain)

    assert_response :success
  end

  test "refresh: reuse keeps the family revocation policy and deletes every auth cookie" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = ClientToken.create!(user: clients(:one))
    first = token.rotate_refresh_token!
    post_refresh(first)

    assert_response :success

    post_refresh(first)

    assert_invalid_refresh_response
    assert_cookie_deleted(REFRESH)
    assert_not_predicate token.reload.discard_at, :future?, "reuse must revoke the token family"
  end

  test "refresh: a DBSC-bound session presented without its bound cookie is refused and the DBSC cookie deleted" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = ClientToken.create!(user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.update_columns(
      user_token_binding_method_id: ClientTokenBindingMethod::DBSC,
      user_token_dbsc_status_id: ClientTokenDbscStatus::ACTIVE,
      dbsc_session_id: "bound-#{SecureRandom.hex(8)}",
    )

    logs = capture_logs { post_refresh(refresh_plain, dbsc: "other-#{SecureRandom.hex(8)}") }

    assert_invalid_refresh_response
    [REFRESH, DBSC].each { |name| assert_cookie_deleted(name) }
    assert_equal %w(dbsc_cookie binding_denied credential_rejection),
                 auth_rejection_events(logs).sole.values_at("credential_kind", "reason", "category")
  end

  # --- Observability and oracle ------------------------------------------------------------------

  test "refusal reasons share status, body, and cookie writes, and the log carries no credential" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = ClientToken.create!(user: clients(:one))
    token.rotate_refresh_token!
    secret_verifier = SecureRandom.urlsafe_base64(32)
    observations =
      {
        "token_not_found" => "missing#{SecureRandom.hex(6)}.#{secret_verifier}",
        "invalid_digest" => "#{token.public_id}.#{secret_verifier}",
        "invalid_format" => "garbage#{secret_verifier}",
      }.map do |reason, value|
        logs = capture_logs { post_refresh(value) }
        event = auth_rejection_events(logs).sole

        assert_equal reason, event.fetch("reason")
        assert_equal "app", event.fetch("surface")
        assert_predicate event.fetch("request_id"), :present?
        assert_not_includes logs, secret_verifier, "the log must not carry the presented verifier"
        [response.status, response.body, AUTH_COOKIES.map { |name| set_cookie_entries(name) }]
      end

    assert_equal 1, observations.uniq.size, "refusal reasons must not be distinguishable from outside"
  end

  # --- System failures are not credential refusals -----------------------------------------------

  test "a database failure while resolving the RP access cookie returns 503 and preserves credentials" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    resource = clients(:one)
    token = ClientToken.create!(user: resource)
    cookies[ACCESS] =
      begin
        rc0_actor = resource
        rc0_type = { Client => "client", Visitor => "visitor", Operator => "operator" }.fetch(rc0_actor.class)
        rc0_realm = { "client" => "app", "visitor" => "com", "operator" => "org" }.fetch(rc0_type)
        rc0_root_model = {
          "client" => ClientToken,
          "visitor" => VisitorToken,
          "operator" => OperatorToken,
        }.fetch(rc0_type)
        rc0_root = rc0_root_model.find_by(public_id: token.public_id) || surface_token(rc0_realm.to_sym, rc0_actor)
        rc0_registered = OidcClientRegistry.find!(
          {
            "app" => "base-app-ww",
            "com" => "base-com-ww",
            "org" => "base-org-ww",
          }.fetch(rc0_realm),
        )
        rc0_rp_model = {
          "client" => ClientRpSession,
          "visitor" => VisitorRpSession,
          "operator" => OperatorRpSession,
        }.fetch(rc0_type)
        rc0_fk = {
          "client" => :client_token_id,
          "visitor" => :visitor_token_id,
          "operator" => :operator_token_id,
        }.fetch(rc0_type)
        rc0_rp = rc0_rp_model.create!(
          rc0_fk => rc0_root.id, :device_session_id => rc0_root.device_session_id,
          :oidc_client_id => rc0_registered.client_id, :oidc_scope => "openid profile",
          :oidc_jti => SecureRandom.uuid, :oidc_auth_time => Time.current,
          :refresh_token_expires_at => 10.minutes.from_now,
        )
        AuthenticationTokenService.encode(
          rc0_actor, host: host, resource_type: rc0_type,
                     session_public_id: rc0_root.public_id, base_session_public_id: rc0_root.public_id,
                     oidc_sid: rc0_rp.public_id, oidc_jti: rc0_rp.oidc_jti,
                     expires_at: 5.minutes.from_now, scopes: %w(openid profile),
                     issuer: OidcIssuer.for_resource_type(rc0_type), audiences: [rc0_registered.aud],
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rc0_registered),
                     subject: OidcSubject.for(rc0_actor, resource_type: rc0_type), client_id: rc0_registered.client_id,
        )
      end

    ClientRpSession.stub(:includes, ->(*) { raise ActiveRecord::ConnectionNotEstablished }) do
      get("/?ri=jp")

      assert_response :service_unavailable
      assert_no_set_cookie(ACCESS)
    end
  end

  test "an issuer failure during refresh propagates instead of becoming an invalid credential" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = ClientToken.create!(user: clients(:one))
    refresh_plain = token.rotate_refresh_token!

    AcmeRefreshTokenIssuer.stub(:call, ->(**) { raise ActiveRecord::StatementInvalid, "injected" }) do
      assert_raises(ActiveRecord::StatementInvalid) { post_refresh(refresh_plain) }
    end
  end

  test "a database failure in the DBSC endpoint's refresh lookup propagates" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = ClientToken.create!(user: clients(:one))
    refresh_plain = token.rotate_refresh_token!

    ClientToken.stub(:find_by, ->(*) { raise ActiveRecord::ConnectionNotEstablished }) do
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        post "/edge/v0/token/dbsc",
             headers: { "Accept" => "application/json", "Cookie" => "#{REFRESH}=#{Rack::Utils.escape(refresh_plain)}" },
             as: :json
      end
    end
  end

  private

  def surface_resource(surface)
    case surface
    when :app then clients(:one)
    when :com then Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    when :org then operators(:one)
    end
  end

  def surface_token(surface, resource)
    case surface
    when :app then ClientToken.create!(user: resource)
    when :com then VisitorToken.create!(visitor: resource)
    when :org then OperatorToken.create!(staff: resource)
    end
  end

  def post_refresh(refresh_plain, dbsc: nil)
    cookie = "#{REFRESH}=#{Rack::Utils.escape(refresh_plain)}"
    cookie += "; #{DBSC}=#{Rack::Utils.escape(dbsc)}" if dbsc
    post("/edge/v0/token/refresh", headers: { "Accept" => "application/json", "Cookie" => cookie }, as: :json)
  end

  def assert_invalid_refresh_response
    assert_response :unauthorized
    assert_equal "invalid_refresh_token", response.parsed_body.fetch("error_code")
    assert_equal %w(error error_code), response.parsed_body.keys.sort
  end

  def capture_logs
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    previous = Rails.logger
    Rails.logger = logger
    yield
    io.string
  ensure
    Rails.logger = previous
  end

  def auth_rejection_events(logs)
    logs.each_line.filter_map do |line|
      json = line[/\{.*\}/]
      next unless json

      parsed = JSON.parse(json)
      parsed["data"] if parsed["event"] == "auth.credential_rejected"
    rescue JSON::ParserError
      nil
    end
  end
end
