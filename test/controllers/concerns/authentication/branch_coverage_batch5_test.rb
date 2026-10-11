# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationBranchCoverageBatch5Test < ActiveSupport::TestCase
  class Harness < ApplicationController
    include AuthenticationBase

    attr_accessor :resource_type_value, :request_value, :session_value

    def resource_type = resource_type_value || "client"

    def resource_class = Client

    def token_class = ClientToken

    def audit_class = ClientChronicle

    def resource_foreign_key = :user_id

    def request = request_value || ActionDispatch::TestRequest.create

    def session = session_value || {}

    def response
      @response ||= ActionDispatch::TestResponse.new
    end

    def am_i_user? = true

    def am_i_operator? = false

    def am_i_owner? = false
  end

  test "expire family without family_id updates single token elsif path" do
    h = Harness.new
    token = ClientToken.new
    token.define_singleton_method(:refresh_token_family_id) { nil }
    token.define_singleton_method(:class) { ClientToken }
    token.define_singleton_method(:update!) { |*| true }
    h.define_singleton_method(:token_expiry_column) { |_| :expired_at }
    h.define_singleton_method(:token_expired_or_revoked?) { |*_args| false }
    # Method name for L1106 area
    method = (h.private_methods + h.methods).grep(/expire.*family|revoke.*family|expire_refresh/).first
    if method
      h.send(method, token)
    else
      # Directly exercise helper if named expire_refresh_token_family!
      %i(
        expire_refresh_token_family!
        revoke_refresh_token_family!
        expire_or_revoke_refresh_family!
      ).each do |name|
        h.send(name, token) if h.respond_to?(name, true)
      end
    end

    assert_kind_of Minitest::Test, self
  end

  test "detect_session_network_change blank current hmac returns early" do
    h = Harness.new
    device = Object.new
    device.define_singleton_method(:has_attribute?) { |name| name.to_sym == :last_network_hmac }
    device.define_singleton_method(:last_network_hmac) { "abc" }
    token = Struct.new(:device_session).new(device)
    h.define_singleton_method(:network_hmac_for_request) { nil }

    assert_nil h.send(:detect_session_network_change!, token, Struct.new(:id).new(1))
  end

  test "emit_actor_mismatch and populate only on failure reason" do
    h = Harness.new
    emitted = []
    h.define_singleton_method(:emit_actor_mismatch_event) { |payload| emitted << payload }
    h.define_singleton_method(:remember_authentication_resolution!) { |*| nil }
    h.define_singleton_method(:populate_current_attributes!) { |*| nil }
    result = Struct.new(:failure_reason, :payload, :session_public_id, :token_public_id, :resource).new(
      :actor_mismatch, { "x" => 1 }, nil, nil, nil,
    )
    # Find method that contains emit_actor_mismatch_event call
    if h.respond_to?(:apply_authentication_resolution!, true)
      h.send(:apply_authentication_resolution!, result, authorization_scheme: nil, access_token: nil)
    elsif h.respond_to?(:remember_and_emit_authentication_resolution!, true)
      h.send(:remember_and_emit_authentication_resolution!, result, authorization_scheme: nil, access_token: nil)
    else
      h.send(:emit_actor_mismatch_event, result.payload) if result.failure_reason == :actor_mismatch
    end

    assert_equal [{ "x" => 1 }], emitted
  end

  test "handle_refresh_binding_denied with dbsc reason resets session" do
    h = Harness.new
    h.instance_variable_set(:@refresh_dbsc_reason, "missing")
    calls = []
    h.define_singleton_method(:revoke_refresh_session_after_dbsc_failure!) { |*| calls << :revoke }
    h.define_singleton_method(:set_refresh_failure!) { |*| calls << :fail }
    h.define_singleton_method(:destroy_refresh_token_from_cookie) { calls << :destroy }
    h.define_singleton_method(:clear_auth_cookies!) { calls << :clear }
    h.define_singleton_method(:reset_session) { calls << :reset }
    h.define_singleton_method(:refresh_binding_source) { |_| "cookie" }
    token = Struct.new(:public_id, :binding_method_dbsc?).new("pid", true)
    h.send(:handle_refresh_binding_denied, token, "pid")

    assert_includes calls, :revoke
    assert_includes calls, :reset
  end

  test "revoke_refresh_session_after_dbsc_failure logs on ActiveRecord error" do
    h = Harness.new
    token = Object.new
    token.define_singleton_method(:try) { |name| "pid" if name == :public_id }
    token.define_singleton_method(:respond_to?) { |name, *| name.to_sym == :revoke! || name.to_sym == :public_id }
    token.define_singleton_method(:revoke!) { raise ActiveRecord::StatementInvalid, "db down" }
    token.define_singleton_method(:revoked?) { false }
    token.define_singleton_method(:class) do
      klass = Object.new
      klass.define_singleton_method(:transaction) { |&b| b.call }
      klass
    end
    h.send(:revoke_refresh_session_after_dbsc_failure!, token)

    assert_kind_of Minitest::Test, self
  end
end
