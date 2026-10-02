# frozen_string_literal: true

require "test_helper"

class PalmJumpSignEntryTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "native apps start Palm with POST /sign with S256 and the registered Palm callback" do
    %w(app-ios-rp app-android-rp).each do |client_id|
      host! "palm-jp.umaxica.app"
      https!
      post "/sign", params: {
        client_id: client_id,
        response_type: "code",
        scope: "openid palm.read",
        redirect_uri: "https://palm-jp.umaxica.app/oidc/callback",
        code_challenge: "a" * 43,
        code_challenge_method: "S256",
        state: "#{client_id}-state",
        nonce: "app-nonce",
        ri: "us",
      }

      assert_response :see_other
      gateway = URI.parse(response.location)

      assert_equal "jump.umaxica.net", gateway.host
      rt = Rack::Utils.parse_nested_query(gateway.query).fetch("rt")
      payload, = JWT.decode(rt, nil, false)
      query = Rack::Utils.parse_nested_query(URI.parse(payload.fetch("url")).query)

      assert_equal "https://palm-jp.umaxica.app", payload.fetch("iss")
      assert_equal "https://www.umaxica.app/oauth/authorize", payload.fetch("url").split("?").first
      assert_equal client_id, query.fetch("client_id")
      assert_equal "https://palm-jp.umaxica.app/oidc/callback", query.fetch("redirect_uri")
      assert_equal "#{client_id}-state", query.fetch("state")
      assert_equal "app-nonce", query.fetch("nonce")
      assert_nil query["code_verifier"]
      assert_operator response.headers["Set-Cookie"].to_s.bytesize, :<, 4096
    end
  end

  test "GET /sign renders the neutral page carrying the native request without starting a flow" do
    host! "palm-jp.umaxica.app"
    https!
    get "/sign", params: {
      client_id: "app-ios-rp",
      response_type: "code",
      scope: "openid palm.read",
      redirect_uri: "https://palm-jp.umaxica.app/oidc/callback",
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      state: "page-state",
      nonce: "page-nonce",
      ri: "jp",
    }

    assert_response :ok
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select "form[method=post][action=?]", "/sign?ri=jp" do
      assert_select "input[type=hidden][name=client_id][value=app-ios-rp]"
      assert_select "input[type=hidden][name=redirect_uri][value=?]", "https://palm-jp.umaxica.app/oidc/callback"
      assert_select "input[type=hidden][name=code_challenge][value=?]", "a" * 43
      assert_select "input[type=hidden][name=state][value=page-state]"
      assert_select "input[type=hidden][name=nonce][value=page-nonce]"
    end
    assert_not session.key?(Palm::App::Sign::EntriesController::PENDING_FLOWS_SESSION_KEY)
  end

  test "GET /sign labels its heading and submit with the shared continue translation" do
    host! "palm-jp.umaxica.app"
    https!
    get "/sign", params: {
      client_id: "app-ios-rp",
      response_type: "code",
      scope: "openid palm.read",
      redirect_uri: "https://palm-jp.umaxica.app/oidc/callback",
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      state: "page-state",
      nonce: "page-nonce",
      ri: "jp",
    }

    assert_response :ok
    assert_select "h1", text: I18n.t("actions.continue")
    assert_select "input[type=submit][value=?]", I18n.t("actions.continue")
  end

  test "GET /sign refuses an unsupported client and a missing code challenge" do
    host! "palm-jp.umaxica.app"
    https!
    valid = {
      client_id: "app-ios-rp",
      response_type: "code",
      scope: "openid palm.read",
      redirect_uri: "https://palm-jp.umaxica.app/oidc/callback",
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      state: "page-state",
      nonce: "page-nonce",
      ri: "jp",
    }
    [{ client_id: "core-app" }, { code_challenge: nil },
     { redirect_uri: "https://evil.example/callback" },].each do |override|
      get "/sign", params: valid.merge(override)

      assert_response :bad_request
    end
  end

  test "the former Palm /sign/in entry no longer exists" do
    host! "palm-jp.umaxica.app"
    https!
    get "/sign/in", params: { ri: "jp" }

    assert_response :not_found
  end

  test "Palm refuses invalid S256 boundaries unsupported clients and unregistered callbacks" do
    host! "palm-jp.umaxica.app"
    https!
    valid = {
      client_id: "app-ios-rp",
      response_type: "code",
      scope: "openid palm.read",
      redirect_uri: "https://palm-jp.umaxica.app/oidc/callback",
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      state: "app-state",
      nonce: "app-nonce",
      ri: "jp",
    }
    [{ code_challenge: "a" * 42 }, { code_challenge: "a" * 44 }, { code_challenge: "!" * 43 },
     { code_challenge: nil }, { code_challenge_method: "plain" }, { state: "" }, { nonce: nil },
     { client_id: "unknown" }, { client_id: "core-app" },
     { redirect_uri: "umaxica://oidc/callback" }, { redirect_uri: "https://evil.example/callback" },].each do |override|
      post "/sign", params: valid.merge(override)

      assert_response :bad_request
    end
  end

  test "Palm accepts a Base Jump return only for the initiating browser state and hands the code to the app" do
    {
      "app-ios-rp" => "umaxica://oidc/callback",
      "app-android-rp" => "com.umaxica.app:/oidc/callback",
    }.each do |client_id, completion|
      host! "palm-jp.umaxica.app"
      https!
      post "/sign", params: {
        client_id: client_id,
        response_type: "code",
        scope: "openid palm.read",
        redirect_uri: "https://palm-jp.umaxica.app/oidc/callback",
        code_challenge: "a" * 43,
        code_challenge_method: "S256",
        state: "app-state",
        nonce: "app-nonce",
        ri: "jp",
      }

      assert_response :see_other

      key = OpenSSL::PKey::EC.generate("secp384r1")
      jwk = JWT::JWK.new(key, kid: "palm-return-test").export.stringify_keys.except("d").merge(
        "alg" => "ES384",
        "use" => "sig",
      )
      cache = ActiveSupport::Cache::MemoryStore.new
      cache.write(
        "jump_rt:return_jwks:#{Digest::SHA256.hexdigest("https://jump.umaxica.net/.well-known/jwks.json")}",
        { "keys" => [jwk] },
      )
      now = Time.current.to_i
      claims = {
        schema: 1,
        iss: "https://jump.umaxica.net",
        aud: "https://palm-jp.umaxica.app",
        sub: "jump-redirect",
        iat: now,
        nbf: now,
        exp: now + 30,
        jti: SecureRandom.uuid,
        rpl: "reuse",
        dst: "internal",
        src: "https://www.umaxica.app",
        url: "https://palm-jp.umaxica.app/oidc/callback?code=code-from-base&state=app-state",
      }
      rt = JWT.encode(claims, key, "ES384", { typ: "JWT", kid: "palm-return-test" })
      Rails.stub(:cache, cache) do
        get "/oidc/callback", params: { code: "code-from-base", state: "app-state", rt: rt }
      end

      assert_response :see_other
      assert_equal "https://palm-jp.umaxica.app/oidc/callback?code=code-from-base&state=app-state", response.location
      get "/oidc/callback", params: { code: "tampered-code", state: "app-state" }

      assert_response :bad_request
      get "/oidc/callback", params: { code: "code-from-base", state: "app-state" }

      assert_response :see_other
      target = URI.parse(response.location)

      assert_equal completion, target.to_s.split("?").first
      assert_equal({ "code" => "code-from-base", "state" => "app-state" }, Rack::Utils.parse_nested_query(target.query))
      assert_not session.key?(Palm::App::Sign::EntriesController::PENDING_FLOWS_SESSION_KEY)
      Rails.stub(:cache, cache) do
        get "/oidc/callback", params: { code: "code-from-base", state: "app-state", rt: rt }
      end

      assert_response :bad_request
      get "/oidc/callback", params: { code: "code-from-base", state: "app-state" }

      assert_response :bad_request
    end
  end

  # Jump RTs are reusable navigation instructions; one-time behavior belongs to the receiver's
  # own protocol state. A fresh, validly signed RT for an unknown or already completed state is
  # refused by Palm's pending-flow check, not by Jump replay tracking.
  test "a valid Jump return cannot complete an unknown or finished Palm flow" do
    key = OpenSSL::PKey::EC.generate("secp384r1")
    jwk = JWT::JWK.new(key, kid: "palm-return-test").export.stringify_keys.except("d").merge(
      "alg" => "ES384",
      "use" => "sig",
    )
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.write(
      "jump_rt:return_jwks:#{Digest::SHA256.hexdigest("https://jump.umaxica.net/.well-known/jwks.json")}",
      { "keys" => [jwk] },
    )
    now = Time.current.to_i
    claims = {
      schema: 1,
      iss: "https://jump.umaxica.net",
      aud: "https://palm-jp.umaxica.app",
      sub: "jump-redirect",
      iat: now,
      nbf: now,
      exp: now + 30,
      jti: SecureRandom.uuid,
      rpl: "reuse",
      dst: "internal",
      src: "https://www.umaxica.app",
      url: "https://palm-jp.umaxica.app/oidc/callback?code=code-from-base&state=never-started",
    }
    rt = JWT.encode(claims, key, "ES384", { typ: "JWT", kid: "palm-return-test" })
    host! "palm-jp.umaxica.app"
    https!

    Rails.stub(:cache, cache) do
      get "/oidc/callback", params: { code: "code-from-base", state: "never-started", rt: rt }
    end

    assert_response :bad_request
    assert_not session.key?(Palm::App::Sign::EntriesController::PENDING_FLOWS_SESSION_KEY)
  end

  test "Palm refuses an unsolicited callback without a verified Jump return" do
    host! "palm-jp.umaxica.app"
    https!
    get "/oidc/callback", params: { code: "unsolicited", state: "unknown" }

    assert_response :bad_request
  end

  # Each case runs in a fresh browser so the two-flow limit never decides the outcome.
  test "state and nonce byte boundaries reject zero and 257 and accept one 255 and 256" do
    valid = {
      client_id: "app-ios-rp",
      response_type: "code",
      scope: "openid palm.read",
      redirect_uri: "https://palm-jp.umaxica.app/oidc/callback",
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      state: "initial-state",
      nonce: "initial-nonce",
      ri: "jp",
    }
    %i(state nonce).each do |field|
      [0, 1, 255, 256, 257].each do |length|
        reset!
        host! "palm-jp.umaxica.app"
        https!
        query = valid.merge(:state => "#{field}-#{length}", field => "a" * length)
        post "/sign", params: query

        assert_response(length.between?(1, 256) ? :see_other : :bad_request)
      end
      reset!
      host! "palm-jp.umaxica.app"
      https!
      post "/sign", params: valid.merge(:state => "#{field}-unicode", field => "あ" * 86)

      assert_response :bad_request
    end
  end

  test "pending flow expiry is exclusive at 600 seconds" do
    valid = {
      client_id: "app-ios-rp",
      response_type: "code",
      scope: "openid palm.read",
      redirect_uri: "https://palm-jp.umaxica.app/oidc/callback",
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      nonce: "nonce",
      ri: "jp",
    }
    started = Time.current.change(usec: 0)
    [599, 600, 601].each do |age|
      reset!
      host! "palm-jp.umaxica.app"
      https!
      travel_to(started) do
        post "/sign", params: valid.merge(state: "expires-#{age}")

        assert_response :see_other
      end
      travel_to(started + age.seconds) do
        post "/sign", params: valid.merge(state: "expires-#{age}")

        assert_response((age < 600) ? :bad_request : :see_other, "age #{age}")
      end
    end
  end

  # BVA on the two-flow limit: the third live flow is refused explicitly and the two earlier flows
  # are kept; nothing is evicted silently. A slot frees only when a flow expires.
  test "a third live pending flow is refused and the two earlier flows stay pending" do
    host! "palm-jp.umaxica.app"
    https!
    valid = {
      client_id: "app-ios-rp",
      response_type: "code",
      scope: "openid palm.read",
      redirect_uri: "https://palm-jp.umaxica.app/oidc/callback",
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      nonce: "nonce",
      ri: "jp",
    }
    started = Time.current.change(usec: 0)
    travel_to(started) do
      post "/sign", params: valid.merge(state: "first")

      assert_response :see_other
    end
    travel_to(started + 1.second) do
      post "/sign", params: valid.merge(state: "second")

      assert_response :see_other
      post "/sign", params: valid.merge(state: "third")

      assert_response :bad_request
      assert_nil response.location
      assert_equal %w(first second),
                   session[Palm::App::Sign::EntriesController::PENDING_FLOWS_SESSION_KEY].keys.sort
    end
    travel_to(started + 600.seconds) do
      post "/sign", params: valid.merge(state: "third")

      assert_response :see_other
      assert_equal %w(second third),
                   session[Palm::App::Sign::EntriesController::PENDING_FLOWS_SESSION_KEY].keys.sort
    end
  end

  test "expired Palm callback prunes its browser continuity and removes the empty container" do
    host! "palm-jp.umaxica.app"
    https!
    started = Time.current.change(usec: 0)
    travel_to(started) do
      post "/sign", params: {
        client_id: "app-ios-rp",
        response_type: "code",
        scope: "openid palm.read",
        redirect_uri: "https://palm-jp.umaxica.app/oidc/callback",
        code_challenge: "a" * 43,
        code_challenge_method: "S256",
        state: "expired-state",
        nonce: "nonce",
        ri: "jp",
      }

      assert_response :see_other
    end
    travel_to(started + 600.seconds) do
      get "/oidc/callback", params: { code: "expired-code", state: "expired-state" }

      assert_response :bad_request
      assert_not session.key?(Palm::App::Sign::EntriesController::PENDING_FLOWS_SESSION_KEY)
    end
  end
end
