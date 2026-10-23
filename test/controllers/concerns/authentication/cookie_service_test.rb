# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationCookieServiceTest < ActiveSupport::TestCase
  class MockRequest
    attr_accessor :headers, :url, :host

    def initialize
      @headers = {}
      @url = "https://app.example.com/"
      @host = "app.example.com"
    end

    def ssl?
      true
    end
  end

  class MockCookies
    attr_accessor :cookies_hash

    def initialize
      @cookies_hash = {}
    end

    delegate :[], to: :@cookies_hash

    delegate :[]=, to: :@cookies_hash

    def delete(key, *)
      @cookies_hash.delete(key)
    end

    def encrypted
      self
    end
  end

  test "access_cookie_key returns access cookie name" do
    cookies = MockCookies.new
    request = MockRequest.new
    service = AuthenticationCookieService.new(cookies, request)

    assert_equal "auth_access", service.access_cookie_key
  end

  test "refresh_cookie_key returns refresh cookie name" do
    cookies = MockCookies.new
    request = MockRequest.new
    service = AuthenticationCookieService.new(cookies, request)

    assert_equal "auth_refresh", service.refresh_cookie_key
  end

  test "extract_access_token_from_request returns token from authorization header" do
    cookies = MockCookies.new
    request = MockRequest.new
    request.headers["Authorization"] = "Bearer abc123token"
    service = AuthenticationCookieService.new(cookies, request)

    result = service.extract_access_token_from_request

    assert_equal "abc123token", result
  end

  test "extract_access_token_from_request accepts lowercase bearer scheme" do
    cookies = MockCookies.new
    request = MockRequest.new
    request.headers["Authorization"] = "bearer abc123token"
    service = AuthenticationCookieService.new(cookies, request)

    result = service.extract_access_token_from_request

    assert_equal "abc123token", result
  end

  test "extract_access_token_from_request returns nil for invalid prefix" do
    cookies = MockCookies.new
    request = MockRequest.new
    request.headers["Authorization"] = "Basic abc123token"
    service = AuthenticationCookieService.new(cookies, request)

    result = service.extract_access_token_from_request

    assert_nil result
  end

  test "extract_access_token_from_request falls back to cookie" do
    cookies = MockCookies.new
    cookies.cookies_hash["auth_access"] = "cookie_token"
    request = MockRequest.new
    service = AuthenticationCookieService.new(cookies, request)

    result = service.extract_access_token_from_request

    assert_equal "cookie_token", result
  end

  test "extract_access_token_from_request returns nil when no token present" do
    cookies = MockCookies.new
    request = MockRequest.new
    service = AuthenticationCookieService.new(cookies, request)

    result = service.extract_access_token_from_request

    assert_nil result
  end

  test "extract_access_token_from_request prefers bearer token over cookie" do
    cookies = MockCookies.new
    cookies.cookies_hash["auth_access"] = "cookie_token"
    request = MockRequest.new
    request.headers["Authorization"] = "Bearer bearer_token"
    service = AuthenticationCookieService.new(cookies, request)

    result = service.extract_access_token_from_request

    assert_equal "bearer_token", result
  end

  test "set_auth_cookies writes access and refresh cookies" do
    cookies = MockCookies.new
    request = MockRequest.new
    service = AuthenticationCookieService.new(cookies, request)

    service.set_auth_cookies(
      access_token: "access-token",
      refresh_token: "refresh-token",
      access_ttl: 5.minutes,
      refresh_ttl: 30.days,
    )

    assert_equal "access-token", cookies.cookies_hash["auth_access"][:value]
    assert_equal "refresh-token", cookies.cookies_hash["auth_refresh"][:value]
  end

  test "clear_auth_cookies deletes all auth cookies" do
    cookies = MockCookies.new
    request = MockRequest.new
    service = AuthenticationCookieService.new(cookies, request)
    cookies.cookies_hash["auth_access"] = "access-token"
    cookies.cookies_hash["auth_refresh"] = "refresh-token"

    service.clear_auth_cookies

    assert_empty cookies.cookies_hash
  end

  test "auth cookie deletion options preserve security attributes" do
    env = ActiveSupport::EnvironmentInquirer.new("production")
    cookies = MockCookies.new
    request = MockRequest.new
    service = AuthenticationCookieService.new(cookies, request)

    Rails.stub(:env, env) do
      options = service.auth_cookie_deletion_options

      assert_equal "/", options[:path]
      assert_equal :strict, options[:same_site]
      assert options[:secure]
      assert_not options.key?(:partitioned)
      assert_not options.key?(:domain)
      assert_not options.key?(:httponly)
      assert_not options.key?(:expires)
    end
  end
end
