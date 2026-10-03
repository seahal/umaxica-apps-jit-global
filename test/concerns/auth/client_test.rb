# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthClientTest < ActiveSupport::TestCase
  fixtures :client_statuses

  class FormatMock
    attr_accessor :format_type

    def initialize(format_type = :html)
      @format_type = format_type
    end

    def json?
      @format_type == :json
    end
  end

  class DummyClass
    include SessionLimitGate
    include AuthenticationClient

    attr_accessor :session, :cookies, :request, :response

    def initialize
      @session = {}
      @cookies = CookieMock.new
      @response = ResponseMock.new
      format = FormatMock.new
      @request = OpenStruct.new(host: "id.app.localhost", headers: {}, user_agent: "TestAgent", format: format)
    end

    def reset_session
      @session = {}
    end

    def controller_path
      "auth/clients"
    end

    def sign_org_edge_v0_token_dbsc_path
      "/edge/v0/token/dbsc"
    end

    def sign_app_edge_v0_token_dbsc_path
      "/edge/v0/token/dbsc"
    end
  end

  class ResponseMock
    def set_header(_name, _value)
    end
  end

  class CookieMock < Hash
    attr_reader :options

    def initialize
      super
      @options = {}
    end

    def encrypted
      self
    end

    def []=(key, value)
      if value.is_a?(Hash) && value.key?(:value)
        opts = value.dup
        actual_value = opts.delete(:value)
        super(key, actual_value)
        @options[key] = opts
      else
        super(key, value)
      end
    end

    def delete(key, _options = {})
      super(key)
    end

    def options_for(key)
      @options[key]
    end
  end

  setup do
    @obj = DummyClass.new
    @user = Client.create!(status_id: ClientStatus::NOTHING, public_id: SecureRandom.alphanumeric(21))
    ClientToken.where(user_id: @user.id).delete_all
  end

  test "module can be included" do
    assert_kind_of AuthenticationClient, @obj
  end

  test "log_in sets access token in cookie" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    @obj.send(:log_in, @user, establishment: :root_login)

    assert @obj.cookies[::AuthenticationClient::ACCESS_COOKIE_KEY]
    assert_predicate @obj, :logged_in?
    assert_equal @user, @obj.current_client
  end

  test "log_in sets cookie expirations" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    @obj.send(:log_in, @user, establishment: :root_login)

    access_opts = @obj.cookies.options_for(::AuthenticationClient::ACCESS_COOKIE_KEY)
    refresh_opts = @obj.cookies.options_for(::AuthenticationClient::REFRESH_COOKIE_KEY)

    assert_operator access_opts[:expires], :>, 4.minutes.from_now
    assert_operator access_opts[:expires], :<, 6.minutes.from_now
    assert_operator refresh_opts[:expires], :>, 29.days.from_now
    assert_operator refresh_opts[:expires], :<, 31.days.from_now
  end

  test "log_out clears session and current_client" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    @obj.send(:log_in, @user, establishment: :root_login)
    @obj.send(:log_out)

    assert_not_predicate @obj, :logged_in?
    assert_nil @obj.current_client
  end

  test "log_out revokes refresh token and removes cookies" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    @obj.send(:log_in, @user, establishment: :root_login)

    assert_no_difference("ClientToken.count") { @obj.send(:log_out) }

    assert_nil @obj.cookies[::AuthenticationClient::ACCESS_COOKIE_KEY]
    assert_nil @obj.cookies.encrypted[::AuthenticationClient::REFRESH_COOKIE_KEY]
  end

  test "log_in keeps auth cookies host-only for __Host prefix compatibility" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }
    @obj.request.host = "id.app.localhost"

    @obj.send(:log_in, @user, establishment: :root_login)

    assert_not @obj.cookies.options_for(::AuthenticationClient::ACCESS_COOKIE_KEY).key?(:domain)
    assert_not @obj.cookies.options_for(::AuthenticationClient::REFRESH_COOKIE_KEY).key?(:domain)
  end

  test "log_in returns tokens hash" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    tokens = @obj.send(:log_in, @user, establishment: :root_login)

    assert_kind_of Hash, tokens
    assert tokens[:access_token]
    assert tokens[:refresh_token]
    assert_equal "Bearer", tokens[:token_type]
    assert_equal ::AuthenticationBase::ACCESS_TOKEN_TTL.to_i, tokens[:expires_in]
  end

  test "log_in skips cookies for JSON format" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }
    @obj.request.format.format_type = :json

    @obj.send(:log_in, @user, establishment: :root_login)

    assert @obj.cookies[::AuthenticationClient::ACCESS_COOKIE_KEY]
    assert @obj.cookies.encrypted[::AuthenticationClient::REFRESH_COOKIE_KEY]
  end

  test "log_in at the active limit issues nothing, even beside a legacy restricted session" do
    2.times do
      token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
      token.rotate_refresh_token!
    end
    ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    before_ids = ClientToken.where(user_id: @user.id).order(:id).pluck(:id, :user_token_status_id, :discard_at)

    result = @obj.send(:log_in, @user, establishment: :root_login, require_totp_check: false)

    assert_equal :session_limit_pending, result[:status]
    assert_nil @obj.cookies[::AuthenticationClient::ACCESS_COOKIE_KEY]
    assert_equal before_ids,
                 ClientToken.where(user_id: @user.id).order(:id).pluck(:id, :user_token_status_id, :discard_at)
  end
end

# DAMP local route helper aliases for former shared test support.
class AuthClientTest
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
