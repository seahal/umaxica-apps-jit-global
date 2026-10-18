# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthCookieHelpersTest < ActiveSupport::TestCase
  class CookieHarness
    include AuthenticationBase

    attr_accessor :cookies, :request_obj

    def initialize
      @cookies = {}
      @request_obj = MockRequest.new
    end

    def request
      @request_obj
    end

    def resource_type
      "user"
    end

    def resource_class
      Client
    end

    def token_class
      ClientToken
    end

    def audit_class
      ClientChronicle
    end

    def resource_foreign_key
      :user_id
    end

    def sign_in_url_with_pt(_return_to)
      "/sign/in"
    end

    def am_i_user?
      false
    end

    def am_i_staff?
      false
    end

    def am_i_owner?
      false
    end
  end

  class MockRequest
    attr_accessor :host, :remote_ip, :user_agent, :request_id

    def initialize
      @host = "example.com"
      @remote_ip = "127.0.0.1"
      @user_agent = "TestAgent"
      @request_id = "test-123"
    end

    def format
      MockFormat.new
    end

    def headers
      {}
    end
  end

  class MockFormat
    def json?
      false
    end

    def html?
      true
    end
  end

  setup do
    @harness = CookieHarness.new
  end

  test "ACCESS_COOKIE_KEY constant is defined" do
    assert_equal "auth_access", AuthenticationBase::ACCESS_COOKIE_KEY
  end

  test "REFRESH_COOKIE_KEY constant is defined" do
    assert_equal "auth_refresh", AuthenticationBase::REFRESH_COOKIE_KEY
  end

  test "DBSC_COOKIE_KEY constant is defined" do
    assert_equal "auth_dbsc", AuthenticationBase::DBSC_COOKIE_KEY
  end

  test "ACCESS_TOKEN_TTL defaults to 5 minutes" do
    assert_equal 5.minutes.to_i, AuthenticationBase::ACCESS_TOKEN_TTL.to_i
  end

  test "REFRESH_TOKEN_TTL is 30 days" do
    assert_equal 30.days, AuthenticationBase::REFRESH_TOKEN_TTL
  end
end
