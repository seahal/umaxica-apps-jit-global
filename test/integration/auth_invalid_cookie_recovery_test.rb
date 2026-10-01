# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/invalid-browser-credential-recovery.md, Auth. A refused auth browser credential is detached
# with deletions that match the issued cookie's identity, and the request continues anonymous: a
# public HTML page renders, a protected HTML page takes the ordinary sign-in path, and JSON keeps its
# authentication failure contract. Policy states and system failures are not credential refusals.
class AuthInvalidCookieRecoveryTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators

  ACCESS = AuthenticationBase::ACCESS_COOKIE_KEY
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

    # Anonymous Dashboard is 404 with no sign-in redirect (adr/home-dashboard-authentication-boundary.md).
    test "#{surface}: a malformed access cookie on a protected page gets the same 404 as no cookie" do
      host! ENV.fetch(config[:host_env])
      get "/dashboard?ri=jp"

      assert_response :not_found

      cookies[ACCESS] = "malformed"
      get "/dashboard?ri=jp"

      assert_response :not_found
      assert_nil response.location
      assert_cookie_deleted(ACCESS)
      # Only the registered credential deletion reaches the 404; no other cookie is committed.
      assert_equal [ACCESS], set_cookie_names
    end

    test "#{surface}: a HEAD with a malformed access cookie on a protected page detaches it on the 404" do
      host! ENV.fetch(config[:host_env])
      cookies[ACCESS] = "malformed"
      head "/dashboard?ri=jp"

      assert_response :not_found
      assert_cookie_deleted(ACCESS)
    end

    test "#{surface}: a protected page 404 without an access cookie emits no Set-Cookie" do
      host! ENV.fetch(config[:host_env])
      get "/dashboard?ri=jp"

      assert_response :not_found
      assert_empty set_cookie_names
    end

    test "#{surface}: an access cookie naming a session that does not exist is detached" do
      host! ENV.fetch(config[:host_env])
      resource = surface_resource(surface)
      cookies[ACCESS] = jwt_access_token_for(resource, host: host, session_public_id: "missing#{SecureRandom.hex(6)}")

      get "/?ri=jp"

      assert_response :success
      assert_cookie_deleted(ACCESS)
    end

    test "#{surface}: an access cookie for a revoked session is detached" do
      host! ENV.fetch(config[:host_env])
      resource = surface_resource(surface)
      token = surface_token(surface, resource)
      cookies[ACCESS] = jwt_access_token_for(resource, host: host, session_public_id: token.public_id)
      token.update_columns(discard_at: 1.second.ago)

      get "/?ri=jp"

      assert_response :success
      assert_cookie_deleted(ACCESS)
    end

    test "#{surface}: a valid access cookie is kept" do
      host! ENV.fetch(config[:host_env])
      resource = surface_resource(surface)
      token = surface_token(surface, resource)
      cookies[ACCESS] = jwt_access_token_for(resource, host: host, session_public_id: token.public_id)

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
    cookies[ACCESS] = jwt_access_token_for(resource, host: host, session_public_id: token.public_id)[0...-8]

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
      cookies[ACCESS] = AuthenticationToken.encode(
        resource, host: host, session_public_id: token.public_id, resource_type: "client",
                  expires_at: expires_at, jwt_issuer_id: jwt_issuer_id_for_test_host(host, "client"),
      )
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
    cookies[ACCESS] = jwt_access_token_for(resource, host: host, session_public_id: token.public_id)
    token.update_columns(last_used_at: SecurityTokenLifetimes::CLIENT_IDLE_TTL.ago - 1.minute)

    logs = capture_logs { get("/?ri=jp") }

    assert_response :success
    assert_cookie_deleted(ACCESS)
    event = auth_rejection_events(logs).sole

    assert_equal %w(access_cookie idle_timeout lifecycle),
                 event.values_at("credential_kind", "reason", "category")
  end

  test "app: a JSON request with a malformed access cookie keeps the existing 401 contract" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    cookies[ACCESS] = "malformed"

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
    user.update!(
      withdrawal_started_at: 1.day.ago, deactivated_at: Time.current, discard_at: Time.current,
      purge_eligible_at: 31.days.from_now,
    )
    token = ClientToken.create!(user: user)
    cookies[ACCESS] = jwt_access_token_for(user, host: host, session_public_id: token.public_id)

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
    com_access = jwt_access_token_for(visitor, host: com_host, session_public_id: com_token.public_id)

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
    issued = { ACCESS => assert_cookie_issued(ACCESS), REFRESH => assert_cookie_issued(REFRESH) }

    forged = "#{token.public_id}.#{SecureRandom.urlsafe_base64(32)}"
    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           "Cookie" => "#{ACCESS}=#{issued[ACCESS][:value]}; #{REFRESH}=#{Rack::Utils.escape(forged)}",
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

  test "a database failure while resolving the access cookie propagates instead of becoming anonymous" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    resource = clients(:one)
    token = ClientToken.create!(user: resource)
    cookies[ACCESS] = jwt_access_token_for(resource, host: host, session_public_id: token.public_id)

    AuthenticationCurrentResourceResolver.stub(:new, ->(**) { raise ActiveRecord::ConnectionNotEstablished }) do
      error = assert_raises(ActorSupport::ResolutionError) { get("/?ri=jp") }

      assert_kind_of ActiveRecord::ConnectionNotEstablished, error.cause
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
