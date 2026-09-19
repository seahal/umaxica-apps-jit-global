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

    @obj.send(:log_in, @user, skip_login_cooldown: true)

    assert @obj.cookies[::AuthenticationClient::ACCESS_COOKIE_KEY]
    assert_predicate @obj, :logged_in?
    assert_equal @user, @obj.current_client
  end

  test "log_in sets cookie expirations" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    @obj.send(:log_in, @user)

    access_opts = @obj.cookies.options_for(::AuthenticationClient::ACCESS_COOKIE_KEY)
    refresh_opts = @obj.cookies.options_for(::AuthenticationClient::REFRESH_COOKIE_KEY)

    assert_operator access_opts[:expires], :>, 4.minutes.from_now
    assert_operator access_opts[:expires], :<, 6.minutes.from_now
    assert_operator refresh_opts[:expires], :>, 29.days.from_now
    assert_operator refresh_opts[:expires], :<, 31.days.from_now
  end

  test "log_out clears session and current_client" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    @obj.send(:log_in, @user)
    @obj.send(:log_out)

    assert_not_predicate @obj, :logged_in?
    assert_nil @obj.current_client
  end

  test "log_out revokes refresh token and removes cookies" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    @obj.send(:log_in, @user)

    assert_no_difference("ClientToken.count") { @obj.send(:log_out) }

    assert_nil @obj.cookies[::AuthenticationClient::ACCESS_COOKIE_KEY]
    assert_nil @obj.cookies.encrypted[::AuthenticationClient::REFRESH_COOKIE_KEY]
  end

  test "log_in keeps auth cookies host-only for __Host prefix compatibility" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }
    @obj.request.host = "id.app.localhost"

    @obj.send(:log_in, @user)

    assert_not @obj.cookies.options_for(::AuthenticationClient::ACCESS_COOKIE_KEY).key?(:domain)
    assert_not @obj.cookies.options_for(::AuthenticationClient::REFRESH_COOKIE_KEY).key?(:domain)
  end

  test "log_in returns tokens hash" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    tokens = @obj.send(:log_in, @user)

    assert_kind_of Hash, tokens
    assert tokens[:access_token]
    assert tokens[:refresh_token]
    assert_equal "Bearer", tokens[:token_type]
    assert_equal ::AuthenticationBase::ACCESS_TOKEN_TTL.to_i, tokens[:expires_in]
  end

  test "log_in skips cookies for JSON format" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }
    @obj.request.format.format_type = :json

    @obj.send(:log_in, @user)

    assert @obj.cookies[::AuthenticationClient::ACCESS_COOKIE_KEY]
    assert @obj.cookies.encrypted[::AuthenticationClient::REFRESH_COOKIE_KEY]
  end

  test "current_client works with Bearer token" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    token_record =
      OrgTicketRecord.connected_to(role: :writing) do
        ClientToken.create!(user: @user)
      end

    # Generate access token using AuthenticationToken
    access_token = AuthenticationToken.encode(
      @user,
      host: @obj.request.host,
      session_public_id: token_record.public_id,
      resource_type: "client",
      jwt_issuer_id: @obj.send(:auth_jwt_issuer_id),
    )
    @obj.request.headers["Authorization"] = "Bearer #{access_token}"

    assert_equal @user, @obj.current_client
  end

  test "log_in hard rejects when active and restricted sessions already exist" do
    2.times do
      token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
      token.rotate_refresh_token!
    end
    restricted = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted.rotate_refresh_token!(discarded_at: 15.minutes.from_now)
    before_ids = ClientToken.where(user_id: @user.id).order(:id).pluck(:id, :user_token_status_id, :discarded_at)

    result = @obj.send(:log_in, @user, require_totp_check: false, skip_login_cooldown: true)

    assert_equal :session_limit_hard_reject, result[:status]
    assert_equal :forbidden, result[:http_status]
    assert_equal AuthenticationBase::SESSION_LIMIT_HARD_REJECT_MESSAGE, result[:message]
    assert_equal before_ids,
                 ClientToken.where(user_id: @user.id).order(:id).pluck(:id, :user_token_status_id, :discarded_at)
  end

  test "log_in issues restricted session with 15 minute ttl when active sessions reach limit" do
    2.times do
      token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
      token.rotate_refresh_token!
    end

    freeze_time do
      result = @obj.send(:log_in, @user, require_totp_check: false, skip_login_cooldown: true)

      assert_equal :success, result[:status]
      assert result[:restricted]

      restricted = ClientToken.where(user_id: @user.id, user_token_status_id: ClientTokenStatus::RESTRICTED).order(:created_at).last

      assert_not_nil restricted
      assert_in_delta 15.minutes.from_now.to_i, restricted.discarded_at.to_i, 1
    end
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
