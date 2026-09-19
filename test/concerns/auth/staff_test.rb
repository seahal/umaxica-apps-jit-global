# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthStaffTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses, :operator_tokens, :operator_token_kinds, :operator_token_statuses

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
    include AuthenticationOperator

    attr_accessor :session, :cookies, :request, :response

    def initialize
      @session = {}
      @cookies = CookieMock.new
      @response = ResponseMock.new
      @request = OpenStruct.new(
        host: "id.org.localhost", headers: {}, user_agent: "TestAgent",
        format: FormatMock.new,
      )
    end

    def reset_session
      @session = {}
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
    @staff = operators(:one)
    OperatorToken.where(staff_id: @staff.id).delete_all
  end

  test "module can be included" do
    assert_kind_of AuthenticationOperator, @obj
  end

  test "log_in sets access token in cookie" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    @obj.send(:log_in, @staff)

    assert @obj.cookies[::AuthenticationOperator::ACCESS_COOKIE_KEY]
    assert_predicate @obj, :logged_in?
    assert_equal @staff.id, @obj.current_operator.id
  end

  test "log_in sets cookie expirations" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    @obj.send(:log_in, @staff)

    access_opts = @obj.cookies.options_for(::AuthenticationOperator::ACCESS_COOKIE_KEY)
    refresh_opts = @obj.cookies.options_for(::AuthenticationOperator::REFRESH_COOKIE_KEY)

    assert_operator access_opts[:expires], :>, 4.minutes.from_now
    assert_operator access_opts[:expires], :<, 6.minutes.from_now
    assert_operator refresh_opts[:expires], :>, 7.hours.from_now
    assert_operator refresh_opts[:expires], :<, 9.hours.from_now
  end

  test "log_out clears session and current_operator" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    @obj.send(:log_in, @staff)
    @obj.send(:log_out)

    assert_not_predicate @obj, :logged_in?
    assert_nil @obj.current_operator
  end

  test "log_out revokes refresh token and removes cookies" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }
    @obj.send(:log_in, @staff)

    assert_no_difference("OperatorToken.count") { @obj.send(:log_out) }
    assert_nil @obj.cookies[::AuthenticationOperator::ACCESS_COOKIE_KEY]
    assert_nil @obj.cookies.encrypted[::AuthenticationOperator::REFRESH_COOKIE_KEY]
  end

  test "log_in uses host-only cookies" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }
    @obj.request.host = "id.org.localhost"

    @obj.send(:log_in, @staff)

    assert_not @obj.cookies.options_for(::AuthenticationOperator::ACCESS_COOKIE_KEY).key?(:domain)
    assert_not @obj.cookies.options_for(::AuthenticationOperator::REFRESH_COOKIE_KEY).key?(:domain)
  end

  test "log_in returns tokens hash" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    freeze_time do
      tokens = @obj.send(:log_in, @staff)

      assert_kind_of Hash, tokens
      assert tokens[:access_token]
      assert tokens[:refresh_token]
      assert_equal "Bearer", tokens[:token_type]
      assert_equal ::AuthenticationBase::ACCESS_TOKEN_TTL.to_i, tokens[:expires_in]
    end
  end

  test "log_in schedules forced logout and delayed deletion for staff token" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    freeze_time do
      @obj.send(:log_in, @staff)
      token = OperatorToken.where(staff_id: @staff.id).order(created_at: :desc).first

      assert_in_delta 8.hours.from_now.to_i, token.discarded_at.to_i, 1
      assert_in_delta 32.hours.from_now.to_i, token.purged_at.to_i, 1
    end
  end

  test "current_operator works with Bearer token" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    token_record =
      OrgTicketRecord.connected_to(role: :writing) do
        OperatorToken.create!(staff: @staff)
      end

    # Generate access token using AuthenticationToken
    access_token = AuthenticationToken.encode(
      @staff,
      host: @obj.request.host,
      session_public_id: token_record.public_id,
      resource_type: "operator",
      jwt_issuer_id: @obj.send(:auth_jwt_issuer_id),
    )
    @obj.request.headers["Authorization"] = "Bearer #{access_token}"

    assert_equal @staff.id, @obj.current_operator.id
  end
end

# DAMP local route helper aliases for former shared test support.
class AuthStaffTest
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
