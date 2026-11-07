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
    test "anonymous Preference cookie names are stable" do
      assert_equal "__Secure-preference", PreferenceCookieName.anonymous_jwt
      assert_equal "__Secure-experience", PreferenceCookieName.anonymous_experience
      assert_equal "language", PreferenceIoKeys::Cookies::LANGUAGE
      assert_equal "__Host-preference_binding", PreferenceBrowserBinding::COOKIE_NAME
    end
  end

  class JwtConfigurationTest < ActiveSupport::TestCase
    test "issuer and key resolution are explicit for each preference realm" do
      { "preference_app" => "app", "preference_com" => "com", "preference_org" => "org" }.each do |issuer_id, audience|
        issuer = JitSecurityJwtRegistry.issuer(issuer_id)

        assert_equal [audience], issuer.audiences
        assert_equal issuer.current_kid, PreferenceJwtConfiguration.active_kid(issuer_id)
        assert_equal issuer.issuer, PreferenceJwtConfiguration.issuer_for(issuer_id)
        assert_equal issuer.current_key.private_key,
                     PreferenceJwtConfiguration.private_key_for_active(issuer_id)
        assert_equal issuer.public_key_for(issuer.current_kid),
                     PreferenceJwtConfiguration.public_key_for(issuer.current_kid, issuer_id: issuer_id)
      end

      assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
        PreferenceJwtConfiguration.issuer_for("preference")
      end
      assert_equal SecurityJwtRfc9068AccessTokenProfile::CLOCK_SKEW_LEEWAY_SECONDS,
                   PreferenceJwtConfiguration.leeway_seconds
    end

    test "parse_header decodes token header" do
      token = JWT.encode({ foo: "bar" }, nil, "none", { kid: "test_kid" })
      header = PreferenceJwtConfiguration.parse_header(token)

      assert_equal "test_kid", header["kid"]
    end
  end

  class TokenTest < ActiveSupport::TestCase
    setup do
      @preferences = SecurityJwtPreferenceTokenCodec::ANONYMOUS_PREFERENCE_VALUES.transform_values(&:first).freeze
      @host = Rails.configuration.x.boot_config.fetch(:hosts).base_service.host
      @type = "AppPreference"
      @public_id = "test_id"
      @jti = "test_jti"
      @issuer_id = "preference_app"
    end

    test "encode and decode a valid realm token with the closed claim set" do
      token = PreferenceToken.encode(
        @preferences,
        host: @host,
        preference_type: @type,
        public_id: @public_id,
        jti: @jti,
        jwt_issuer_id: @issuer_id,
        issued_at: Time.current,
      )

      assert_not_nil token
      decoded = PreferenceToken.decode(token, host: @host, jwt_issuer_id: @issuer_id)

      assert_not_nil decoded
      assert_equal @preferences, decoded["preferences"]
      assert_equal "app", decoded["aud"]
      assert_equal @public_id, decoded["sub"]
      assert_equal @jti, decoded["jti"]
      assert_equal SecurityJwtPreferenceTokenCodec::ANONYMOUS_CLAIMS.sort, decoded.keys.sort
    end

    test "decode returns nil for invalid host" do
      token = PreferenceToken.encode(
        @preferences,
        host: @host,
        preference_type: @type,
        public_id: @public_id,
        jti: @jti,
        jwt_issuer_id: @issuer_id,
        issued_at: Time.current,
      )

      assert_nil PreferenceToken.decode(token, host: "wrong.host", jwt_issuer_id: @issuer_id)
    end

    test "extract_preferences returns preferences from payload" do
      payload = { "preferences" => { "theme" => "light" } }

      assert_equal({ "theme" => "light" }, PreferenceToken.extract_preferences(payload))
      assert_equal({}, PreferenceToken.extract_preferences(nil))
    end
  end
end

# DAMP local route helper aliases for former shared test support.
class PreferenceSanitizeTestController
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
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

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
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
    %w(AUTH_APP AUTH_ORG ACME_APP ACME_ORG CORE_APP CORE_ORG BASE_APP BASE_ORG).each do |namespace|
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
