# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class JumpRtReturnVerificationTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @jump_private_key = OpenSSL::PKey::EC.generate("secp384r1")
    @jump_public_jwk = JWT::JWK.new(@jump_private_key, kid: "jump-test").export.stringify_keys.except("d").merge(
      "alg" => "ES384",
      "use" => "sig",
    )
    @rails_private_key = OpenSSL::PKey::EC.generate("secp384r1")
    @rails_public_jwk = JWT::JWK.new(@rails_private_key, kid: "acme-app-test").export.stringify_keys.except("d").merge(
      "alg" => "ES384",
      "use" => "sig",
    )
    @now = Time.current.change(usec: 0)
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @previous_cache
  end

  test "rails issued rt can round trip through a stubbed jump gateway and return verifier" do
    with_env(
      "PRIVATE_AUTH_SERVICE_URL" => "www.umaxica.app",
      "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
    ) do
      JumpRtKeyring.stub(:active_kid, "acme-app-test") do
        JumpRtKeyring.stub(:private_key, @rails_private_key) do
          app_origin = acme_app_origin
          rails_rt = JumpRtIssuer.call(
            namespace: "ACME_APP",
            url: "#{app_origin}/",
            dst: "internal",
            now: @now,
            jti: "rails-jti",
          )

          returned_location = stubbed_jump_location(rails_rt)
          returned_rt = Rack::Utils.parse_nested_query(URI.parse(returned_location).query).fetch("rt")
          prime_jump_jwks_cache

          https!
          JumpRtReturnVerifier.stub(:call, verifier_success) do
            get "#{app_origin}/", params: { rt: returned_rt }
          end
        end
      end
    end

    assert_response :see_other
    assert_equal "#{acme_app_origin}/", response.location
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
  end

  test "acme app consumes valid jump return rt and strips it from url" do
    app_origin = acme_app_origin
    https!
    token = sign_return_token(
      aud: app_origin,
      src: "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}",
      url: "#{app_origin}/?ok=1",
    )

    JumpRtReturnVerifier.stub(:call, verifier_success) do
      get "#{app_origin}/", params: { ok: "1", rt: token }
    end

    assert_response :see_other
    assert_equal "#{app_origin}/?ok=1", response.location
  end

  test "acme app rejects invalid jump return rt before normal auth flow" do
    app_origin = acme_app_origin
    https!

    get "#{app_origin}/", params: { rt: "not-a-jwt" }

    assert_response :bad_request
  end

  test "rejected jump return logs do not include the rt token" do
    app_origin = acme_app_origin
    https!
    token = "aaaaaaaa.bbbbbbbb.cccccccc"
    log_io = StringIO.new
    previous_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log_io)
    begin
      get("#{app_origin}/", params: { rt: token })
    ensure
      Rails.logger = previous_logger
    end
    joined = log_io.string

    assert_response :bad_request
    assert_includes joined, "jump_return.rejected"
    assert_not_includes joined, token
    assert_no_match(/rt=#{Regexp.escape(token)}/, joined)
  end

  test "sign app includes jump return verification" do
    assert_includes Auth::App::ApplicationController.ancestors, JumpRtReturnVerification
  end

  test "sign com and org surfaces do not include jump return verification" do
    assert_not_includes Auth::Com::ApplicationController.ancestors, JumpRtReturnVerification
    assert_not_includes Auth::Org::ApplicationController.ancestors, JumpRtReturnVerification
  end

  test "sign app consumes valid jump return rt and strips it from url" do
    sign_origin = sign_app_origin
    https!
    token = sign_return_token(
      aud: sign_origin,
      src: "https://www.app.localhost",
      url: "#{sign_origin}/?ok=1",
    )

    JumpRtReturnVerifier.stub(:call, sign_verifier_success(sign_origin)) do
      get "#{sign_origin}/", params: { ok: "1", rt: token }
    end

    assert_response :see_other
    assert_equal "#{sign_origin}/?ok=1", response.location
  end

  test "sign app rejects invalid jump return rt before normal auth flow" do
    sign_origin = sign_app_origin
    https!

    get "#{sign_origin}/", params: { rt: "not-a-jwt" }

    assert_response :bad_request
  end

  test "sign app runs jump return verification before set_current_context" do
    before_filters =
      Auth::App::ApplicationController._process_action_callbacks.filter_map do |callback|
        callback.filter if callback.kind == :before
      end

    assert_includes before_filters, :verify_jump_return_rt!
    assert_operator before_filters.index(:verify_jump_return_rt!), :<, before_filters.index(:set_current_context)
  end

  test "return verification concern does not register callbacks when included" do
    controller =
      Class.new(ActionController::Base) do # rubocop:disable Rails/ApplicationController
        include JumpRtReturnVerification
      end

    before_filters =
      controller._process_action_callbacks.filter_map do |callback|
        callback.filter if callback.kind == :before
      end

    assert_not_includes before_filters, :verify_jump_return_rt!
  end

  test "core app explicitly runs jump return verification before normal auth flow" do
    before_filters =
      Core::App::ApplicationController._process_action_callbacks.filter_map do |callback|
        callback.filter if callback.kind == :before
      end

    assert_includes before_filters, :verify_jump_return_rt!
    assert_operator before_filters.index(:verify_jump_return_rt!), :<, before_filters.index(:set_current_context)
  end

  private

  def verifier_success
    lambda do |token:, request_url:, request_base_url:|
      assert_predicate token, :present?
      assert_match(%r{\A#{Regexp.escape(acme_app_origin)}/\?(?:ok=1&)?rt=#{Regexp.escape(token)}\z}, request_url)
      assert_equal acme_app_origin, request_base_url

      JumpRtReturnVerifier::Result.new(success: true, payload: {}, error: nil)
    end
  end

  def stubbed_jump_location(rails_rt)
    rails_issuer = JumpRtSurface.issuer_origin("ACME_APP")
    payload, header = JWT.decode(
      rails_rt,
      JWT::JWK.import(@rails_public_jwk).public_key,
      true,
      algorithms: ["ES384"],
      iss: rails_issuer,
      verify_iss: true,
      aud: "https://jump.umaxica.net",
      verify_aud: true,
      verify_iat: false,
      verify_expiration: false,
      verify_not_before: false,
    )

    assert_equal "JWT", header.fetch("typ")
    assert_equal "acme-app-test", header.fetch("kid")
    assert_equal rails_issuer, payload.fetch("iss")
    assert_equal 1, payload.fetch("schema")
    assert_equal "jump-redirect", payload.fetch("sub")
    assert_equal "internal", payload.fetch("dst")
    assert_equal "#{acme_app_origin}/", payload.fetch("url")

    return_rt = sign_return_token(
      aud: acme_app_origin,
      src: payload.fetch("iss"),
      url: payload.fetch("url"),
      jti: "jump-jti",
      iat: @now.to_i,
      nbf: @now.to_i,
      exp: @now.to_i + 30,
    )
    "#{acme_app_origin}/?#{Rack::Utils.build_query(rt: return_rt)}"
  end

  def prime_jump_jwks_cache
    jwks_url = "https://jump.umaxica.net/.well-known/jwks.json"
    cache_key = "jump_rt:return_jwks:#{Digest::SHA256.hexdigest(jwks_url)}"
    Rails.cache.write(cache_key, { "keys" => [@jump_public_jwk] }, expires_in: 30.seconds)
  end

  def sign_return_token(overrides = {})
    iat = @now.to_i
    payload = {
      schema: 1,
      iss: "https://jump.umaxica.net",
      aud: "https://www.app.localhost",
      sub: "jump-redirect",
      iat: iat,
      nbf: iat,
      exp: iat + 30,
      jti: "jump-return-jti",
      src: "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}",
      dst: "internal",
      url: "https://www.app.localhost/",
    }.merge(overrides)

    JWT.encode(payload, @jump_private_key, "ES384", { typ: "JWT", kid: "jump-test" })
  end

  def acme_app_origin
    "https://#{ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")}"
  end

  def sign_app_origin
    "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}"
  end

  def sign_verifier_success(origin)
    lambda do |token:, request_url:, request_base_url:|
      assert_predicate token, :present?
      assert_equal "#{origin}/?ok=1&rt=#{token}", request_url
      assert_equal origin, request_base_url

      JumpRtReturnVerifier::Result.new(success: true, payload: {}, error: nil)
    end
  end

  def with_env(values)
    previous = values.transform_values { |_value| nil }
    values.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end

# DAMP local route helper aliases for former shared test support.
class JumpRtReturnVerificationTest
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
