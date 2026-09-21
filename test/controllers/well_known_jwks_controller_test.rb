# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"
require "openssl"

class WellKnownJwksControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  def self.normalized_host(value)
    value.to_s.strip.sub(/\Ahttps?:\/\//, "").split("/").first
  end

  ENDPOINTS = [
    ["base app", "BASE_APP", normalized_host(ENV.fetch("PUBLIC_BASE_SERVICE_URL", "www.app.localhost"))],
    ["base com", "BASE_COM", normalized_host(ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "www.com.localhost"))],
    ["base org", "BASE_ORG", normalized_host(ENV.fetch("PUBLIC_BASE_STAFF_URL", "www.org.localhost"))],
    ["core app", "CORE_APP", normalized_host(ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"))],
    ["core com", "CORE_COM", normalized_host(ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost"))],
    ["core org", "CORE_ORG", normalized_host(ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost"))],
    ["sign app", "SIGN_APP", normalized_host(ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost"))],
    ["sign com", "SIGN_COM", normalized_host(ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost"))],
    ["sign org", "SIGN_ORG", normalized_host(ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost"))],
  ].freeze

  setup do
    @jwt_env = docker_core_jwt_env
    @previous_env = @jwt_env.transform_values { |_value| nil }
    @jwt_env.each do |key, value|
      @previous_env[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    JitSecurityJwtRegistry.reload!
  end

  teardown do
    @previous_env.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    JitSecurityJwtRegistry.reload!
  end

  ENDPOINTS.each do |name, namespace, host|
    test "#{name} well-known JWKS returns JSON" do
      host! host

      get "/.well-known/jwks.json", headers: browser_headers

      assert_response :success
      assert_equal "application/json", response.media_type
      assert_nil response.headers["Location"]
      assert_predicate response.headers["Set-Cookie"], :blank?
      assert_match(/max-age=3600/, response.headers["Cache-Control"])
      assert_includes response.parsed_body.keys, "keys"
      key = response.parsed_body.fetch("keys").first

      assert_equal JitSecurityJwtRegistry.surface(namespace).current_kid, key.fetch("kid")
      assert_equal "EC", key.fetch("kty")
      assert_equal "P-384", key.fetch("crv")
      assert_equal "ES384", key.fetch("alg")
      assert_equal "sig", key.fetch("use")
      assert_not_equal "none", key.fetch("alg")
      assert_not_includes key.keys, "d"
      assert_not_includes key.keys, "k"
      assert_not_includes key.keys, "pem"
    end
  end

  def docker_core_jwt_env
    key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    env = {
      "AUTH_JWT_ACTIVE_KID" => "auth-test",
      "AUTH_JWT_ISSUER" => "auth-test-issuer",
      "AUTH_JWT_PRIVATE_KEYSET" => JSON.generate("auth-test" => key),
      "AUTH_JWT_PUBLIC_KEYSET" => JSON.generate(keys: []),
      "PREFERENCE_JWT_ACTIVE_KID" => "preference-test",
      "PREFERENCE_JWT_ISSUER" => "preference-test-issuer",
      "PREFERENCE_JWT_PRIVATE_KEYSET" => JSON.generate("preference-test" => key),
      "PREFERENCE_JWT_PUBLIC_KEYSET" => JSON.generate(keys: []),
    }
    ENDPOINTS.each_with_object(env) do |(_name, namespace, _host), jwt_env|
      jwt_env["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      jwt_env["JWT_#{namespace}_PRIVATE_KEY"] = key
      jwt_env["JWT_#{namespace}_PUBLIC_KEYSET"] = JSON.generate(keys: [])
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

    base
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

    base
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

    base
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class WellKnownJwksControllerTest
  private
end
