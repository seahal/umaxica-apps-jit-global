# typed: false
# frozen_string_literal: true

require "test_helper"

# The hard invariant of Restricted Mode: an Emergency session stays an Emergency
# session for its whole life.
#
# Refresh, rotation, renewal and mid-session reissue all mint a replacement
# access token, and every one of them derives the authentication context from
# the same place -- the session row. There is no code path where a continuation
# can produce a Normal token for a session that was established through
# Emergency Access.
class Auth::OrgEmergencySessionContinuityTest < ActiveSupport::TestCase
  include LoginCooldownHelper

  fixtures :operators, :operator_statuses, :operator_tokens, :operator_token_kinds, :operator_token_statuses

  class Harness
    include AuthenticationOperator

    attr_accessor :session, :cookies, :request, :response

    def initialize
      @session = {}
      @cookies = CookieJar.new
      @response = Response.new
      @request = OpenStruct.new(
        host: "id.org.localhost", headers: {}, user_agent: "TestAgent",
        format: Format.new,
        remote_ip: "127.0.0.1", request_id: "test-request",
      )
    end

    def reset_session = @session = {}

    def request_ip_address = "127.0.0.1"

    def sign_org_edge_v0_token_dbsc_path = "/edge/v0/token/dbsc"

    def invoke(name, ...) = send(name, ...)

    class Response
      def set_header(_name, _value) = nil
    end

    class Format
      def json? = false
    end

    class CookieJar < Hash
      def encrypted = self

      def []=(key, value)
        super(key, (value.is_a?(Hash) && value.key?(:value)) ? value[:value] : value)
      end

      def delete(key, *) = super(key)

      def options_for(_key) = {}
    end
  end

  setup do
    @staff = operators(:one)
    @staff.update!(status_id: OperatorStatus::ACTIVE)
    OperatorToken.where(staff_id: @staff.id).delete_all
    @harness = Harness.new
  end

  def claims_of(access_token)
    AuthenticationToken.decode(
      access_token,
      host: "id.org.localhost",
      resource_type: "operator",
      jwt_issuer_id: "surface:SIGN_ORG",
    )
  end

  test "an emergency sign-in records the context on the session row and in the access token" do
    result = @harness.invoke(
      :log_in, @staff, authentication_context: AuthenticationContextValue::EMERGENCY_KEY,
    )

    assert_equal :success, result[:status]

    token = OperatorToken.where(staff_id: @staff.id).order(:id).last

    assert_equal "emergency", token.authentication_context
    assert_equal "emergency", claims_of(result[:access_token]).fetch(AuthenticationContextValue::CLAIM)
  end

  test "a normal sign-in records the normal context and never the emergency one" do
    result = @harness.invoke(:log_in, @staff)
    token = OperatorToken.where(staff_id: @staff.id).order(:id).last

    assert_nil token.authentication_context
    assert_not_predicate token, :emergency_authentication_context?
    assert_equal "normal", claims_of(result[:access_token]).fetch(AuthenticationContextValue::CLAIM)
  end

  test "refresh keeps the emergency context and never upgrades the session" do
    issued = @harness.invoke(
      :log_in, @staff, authentication_context: AuthenticationContextValue::EMERGENCY_KEY,
    )

    refreshed = @harness.invoke(:refresh_access_token, issued[:refresh_token])

    assert_not_nil refreshed[:access_token]
    assert_equal(
      "emergency",
      claims_of(refreshed[:access_token]).fetch(AuthenticationContextValue::CLAIM),
      "a refreshed access token must not silently become a normal session",
    )
    assert_equal "emergency", OperatorToken.where(staff_id: @staff.id).order(:id).last.authentication_context
  end

  test "repeated rotation never drops the emergency context" do
    issued = @harness.invoke(
      :log_in, @staff, authentication_context: AuthenticationContextValue::EMERGENCY_KEY,
    )
    refresh_token = issued[:refresh_token]

    3.times do
      result = @harness.invoke(:refresh_access_token, refresh_token)

      assert_not_nil result[:access_token]
      assert_equal "emergency", claims_of(result[:access_token]).fetch(AuthenticationContextValue::CLAIM)
      refresh_token = result[:refresh_token] || refresh_token
    end
  end

  # Changing mode means ending the session and starting a new one, so the new
  # session must be a new row rather than the old one relabelled.
  test "signing out of an emergency session and signing in normally produces a new normal session" do
    @harness.invoke(:log_in, @staff, authentication_context: AuthenticationContextValue::EMERGENCY_KEY)
    emergency_token = OperatorToken.where(staff_id: @staff.id).order(:id).last

    @harness.invoke(:log_out)

    # The cooldown exists to slow repeated sign-ins, not to describe the mode
    # transition; the transition itself is what this asserts.
    normal = with_login_cooldown(0.seconds) { @harness.invoke(:log_in, @staff) }
    normal_token = OperatorToken.where(staff_id: @staff.id).order(:id).last

    assert_not_equal emergency_token.id, normal_token.id
    assert_equal "emergency", emergency_token.reload.authentication_context,
                 "the terminated session keeps its own history rather than being rewritten"
    assert_nil normal_token.authentication_context
    assert_equal "normal", claims_of(normal[:access_token]).fetch(AuthenticationContextValue::CLAIM)
  end

  # Emergency Access is org only, so app and com have no column to record a
  # context in and no ceremony that could set one. Their sessions report Normal
  # by construction rather than by a lookup that could be made to answer
  # otherwise.
  test "app and com sessions have no authentication context to carry" do
    [ClientToken, VisitorToken].each do |token_class|
      assert_not_includes token_class.column_names, "authentication_context"
      assert_predicate token_class.new.authentication_context_value, :normal?
      assert_not_predicate token_class.new, :emergency_authentication_context?
    end
  end
end
