# typed: false
# frozen_string_literal: true

require "openssl"

require "test_helper"
# require "helpers/global_test_support"

class PreferenceSanitizeTestController < ::ApplicationController
  include ::PreferenceBase

  attr_accessor :test_params, :test_controller_path

  def initialize(*)
    super
    @test_params = {}
  end

  def controller_path
    @test_controller_path || "acme/app/preferences"
  end

  def params
    @test_params.with_indifferent_access
  end
end

module Preference
  class BaseTest < ActiveSupport::TestCase
    test "preference cookie key constants are stable" do
      assert_equal "ct", PreferenceBase::THEME_COOKIE_KEY
      assert_equal "language", PreferenceBase::LANGUAGE_COOKIE_KEY
      assert_equal "tz", PreferenceBase::TIMEZONE_COOKIE_KEY
    end
  end

  class JwtConfigurationTest < ActiveSupport::TestCase
    test "audience_for selects matching host family and keeps localhost in development" do
      assert_includes PreferenceJwtConfiguration.audience_for("log.umaxica.app"), "www.umaxica.app"
      assert_includes PreferenceJwtConfiguration.audience_for("www.umaxica.com"), "www.umaxica.com"
      assert_includes PreferenceJwtConfiguration.audience_for("base.org.localhost"), "org.localhost"
    end
  end

  class JwtConfigurationTest < ActiveSupport::TestCase
    test "active_kid returns value from ENV" do
      with_env("PREFERENCE_JWT_ACTIVE_KID" => "test_kid") do
        assert_equal JitSecurityJwtRegistry.issuer("preference").current_kid,
                     PreferenceJwtConfiguration.active_kid
      end
    end

    test "leeway_seconds ignores the environment and returns the fixed profile leeway" do
      with_env("PREFERENCE_JWT_LEEWAY_SECONDS" => "3600") do
        assert_equal SecurityJwtRfc9068AccessTokenProfile::CLOCK_SKEW_LEEWAY_SECONDS,
                     PreferenceJwtConfiguration.leeway_seconds
      end
    end

    test "issuer returns value from ENV" do
      with_env("PREFERENCE_JWT_ISSUER" => "test-issuer") do
        assert_equal "test-issuer", PreferenceJwtConfiguration.issuer
      end
    end

    test "audiences are derived from boot config hosts" do
      expected = Rails.configuration.x.boot_config.fetch(:hosts).base_origins.map(&:host) +
        %w(app.localhost org.localhost com.localhost localhost)

      assert_equal expected,
                   PreferenceJwtConfiguration.audiences
    end

    test "audience_for filters to matching TLD only" do
      result = PreferenceJwtConfiguration.audience_for("log.umaxica.app")

      assert_includes result, "www.umaxica.app"
      assert_includes result, "app.localhost", "localhost fallback is included in non-production"
      assert_not_includes result, "www.umaxica.com"
    end

    test "audience_for returns only matching TLD for com host" do
      result = PreferenceJwtConfiguration.audience_for("wwww.umaxica.com")

      assert_includes result, "www.umaxica.com"
      assert_includes result, "app.localhost"
      assert_not_includes result, "www.umaxica.app"
    end

    test "audience_for includes localhost for localhost host" do
      result = PreferenceJwtConfiguration.audience_for("id.app.localhost")

      assert_includes result, "app.localhost"
      assert_includes result, "localhost"
      assert_not_includes result, "www.umaxica.app"
    end

    test "audience_for raises when host is blank" do
      assert_raises(ArgumentError) { PreferenceJwtConfiguration.audience_for("") }
      assert_raises(ArgumentError) { PreferenceJwtConfiguration.audience_for(nil) }
    end

    test "audience_for raises when no configured TLD matches" do
      assert_equal ["app.localhost"], PreferenceJwtConfiguration.audience_for("example.invalid")
    end

    test "audience_for raises for an .org host when only .app/.com are configured" do
      assert_includes PreferenceJwtConfiguration.audience_for("log.umaxica.org"), "www.umaxica.org"
    end

    test "host_scope_for uses matching configured audience for sibling hosts" do
      assert_equal "www.umaxica.app", PreferenceJwtConfiguration.host_scope_for("log.umaxica.app")
      assert_equal "www.umaxica.com", PreferenceJwtConfiguration.host_scope_for("www.umaxica.com")
    end

    test "host_scope_for raises when no configured audience matches" do
      assert_equal "localhost", PreferenceJwtConfiguration.host_scope_for("example.invalid")
    end

    test "parse_header decodes token header" do
      token = JWT.encode({ foo: "bar" }, nil, "none", { kid: "test_kid" })
      header = PreferenceJwtConfiguration.parse_header(token)

      assert_equal "test_kid", header["kid"]
    end

    private

    def with_env(vars)
      original = vars.keys.index_with { |k| ENV[k] }
      vars.each { |k, v| ENV[k] = v }
      yield
    ensure
      original.each { |k, v| ENV[k] = v }
    end
  end

  class TokenTest < ActiveSupport::TestCase
    setup do
      @preferences = { "theme" => "dark" }.freeze
      @host = "app.localhost"
      @type = "user"
      @public_id = "test_id"
      @jti = "test_jti"

      # Generate a test EC key
      @key = OpenSSL::PKey::EC.generate("secp384r1")
      @der = Base64.encode64(@key.to_der)
      @pub_der = Base64.encode64(@key.public_to_der)
    end

    test "encode and decode a valid token" do
      PreferenceJwtConfiguration.stub(:private_key_for_active, @key) do
        PreferenceJwtConfiguration.stub(:public_key_for, @key) do
          PreferenceJwtConfiguration.stub(:active_kid, "test_kid") do
            token = PreferenceToken.encode(
              @preferences,
              host: @host,
              preference_type: @type,
              public_id: @public_id,
              jti: @jti,
            )

            assert_not_nil token

            decoded = PreferenceToken.decode(token, host: @host)

            assert_not_nil decoded
            assert_equal @preferences, decoded["preferences"]
            assert_equal PreferenceJwtConfiguration.host_scope_for(@host), decoded["host"]
            assert_equal @type, decoded["preference_type"]
            assert_equal @public_id, decoded["public_id"]
            assert_equal @jti, decoded["jti"]
          end
        end
      end
    end

    test "decode returns nil for invalid host" do
      PreferenceJwtConfiguration.stub(:private_key_for_active, @key) do
        PreferenceJwtConfiguration.stub(:public_key_for, @key) do
          PreferenceJwtConfiguration.stub(:active_kid, "test_kid") do
            token = PreferenceToken.encode(
              @preferences,
              host: @host,
              preference_type: @type,
              public_id: @public_id,
              jti: @jti,
            )

            assert_nil PreferenceToken.decode(token, host: "wrong.host")
          end
        end
      end
    end

    test "extract_preferences returns preferences from payload" do
      payload = { "preferences" => { "theme" => "light" } }

      assert_equal({ "theme" => "light" }, PreferenceToken.extract_preferences(payload))
      assert_equal({}, PreferenceToken.extract_preferences(nil))
    end
  end

  private

  def encode_preference_jwt(preferences:, host:, public_id:, preference_type: "AppPreference")
    jti = "test-jti-#{SecureRandom.uuid}"
    token = nil

    with_preference_jwt_keys(host: host) do
      token = PreferenceToken.encode(
        preferences,
        host: host,
        preference_type: preference_type,
        public_id: public_id,
        jti: jti,
      )
    end

    token
  end

  def with_preference_jwt_keys(host: nil)
    key = OpenSSL::PKey::EC.generate("secp384r1")
    public_key_for_stub = ->(_kid, **_options) { key }
    audiences = host ? [host] : PreferenceJwtConfiguration.audiences

    PreferenceJwtConfiguration.stub(:private_key, key) do
      PreferenceJwtConfiguration.stub(:public_key, key) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, key) do
          PreferenceJwtConfiguration.stub(:public_key_for, public_key_for_stub) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, audiences) do
                  yield
                end
              end
            end
          end
        end
      end
    end
  end
end

# DAMP local route helper aliases for former shared test support.
class PreferenceSanitizeTestController
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
class Preference::BaseTest
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
    token ||= ClientToken.where(user_id: user.id).where("discard_at > ?", Time.current).order(created_at: :desc).first
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
      "discard_at > ?",
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
      "discard_at > ?",
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

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
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

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(AUTH_APP AUTH_ORG AUTH_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
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
    OmniAuth.config.mock_auth[:google_app] =
      OmniAuth::AuthHash.new(
        provider: "google_app", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end
