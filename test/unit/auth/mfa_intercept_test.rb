# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Unit tests for the MFA intercept logic in AuthenticationBase.
# Tests mfa_required_for?, establish_signed_in_session!, and related helpers.
class Auth::MfaInterceptUnitTest < ActiveSupport::TestCase
  fixtures :client_statuses

  test "mfa_required_for? returns false for user without mfa_level_enabled" do
    user = Client.create!(mfa_level_enabled: false)
    controller = build_test_controller

    assert_not controller.send(:mfa_required_for?, user)
  end

  test "mfa_required_for? returns true for user with mfa_level_enabled" do
    user = Client.create!(mfa_level_enabled: true)
    controller = build_test_controller

    assert controller.send(:mfa_required_for?, user)
  end

  test "mfa_required_for? returns true for user with full mfa_level_id" do
    user = Client.create!(mfa_level_id: ClientMfaLevel::FULL, mfa_level_enabled: true)
    controller = build_test_controller

    assert controller.send(:mfa_required_for?, user)
  end

  test "mfa_required_for? returns false for user with nothing mfa_level_id" do
    user = Client.create!(mfa_level_id: ClientMfaLevel::NOTHING)
    controller = build_test_controller

    assert_not controller.send(:mfa_required_for?, user)
  end

  test "mfa_required_for? returns false for non-Client resources" do
    controller = build_test_controller

    assert_not controller.send(:mfa_required_for?, nil)
  end

  test "check_totp_requirement returns mfa_required status for MFA user" do
    user = Client.create!(mfa_level_enabled: true)
    controller = build_test_controller

    result = controller.send(:check_totp_requirement, user)

    assert_equal({ status: :mfa_required }, result)
  end

  test "check_totp_requirement returns nil for non-MFA user" do
    user = Client.create!(mfa_level_enabled: false)
    controller = build_test_controller

    result = controller.send(:check_totp_requirement, user)

    assert_nil result
  end

  test "resolve_mfa_return_to returns nil for blank value" do
    controller = build_test_controller

    assert_nil controller.send(:resolve_mfa_return_to, nil)
    assert_nil controller.send(:resolve_mfa_return_to, "")
  end

  test "resolve_mfa_return_to decodes base64 internal path" do
    controller = build_test_controller
    encoded = Base64.urlsafe_encode64("/settings")

    result = controller.send(:resolve_mfa_return_to, encoded)

    assert_equal "/settings", result
  end

  test "resolve_mfa_return_to rejects external URLs without allowed host" do
    controller = build_test_controller

    result = controller.send(:resolve_mfa_return_to, "https://evil.com/hack")

    assert_nil result
  end

  test "complete_sign_in_or_start_mfa adds auth method to login audit context" do
    user = Client.create!(mfa_level_enabled: false)
    controller = build_test_controller
    captured = nil

    controller.define_singleton_method(:log_in) do |resource, **kwargs|
      captured = [resource, kwargs]
      { status: :success }
    end

    result = controller.send(
      :establish_signed_in_session!,
      user,
      pt: nil,
      ri: "jp",
      auth_method: "secret_credential",
    )

    assert_equal({ status: :success, redirect_path: "/" }, result)
    assert_equal user, captured.first
    assert_not captured.last[:require_totp_check]
    assert_equal({ auth_method: "secret_credential" }, captured.last[:audit_context])
  end

  test "complete_sign_in_or_start_mfa preserves explicit audit context" do
    user = Client.create!(mfa_level_enabled: false)
    controller = build_test_controller
    captured = nil

    controller.define_singleton_method(:log_in) do |resource, **kwargs|
      captured = [resource, kwargs]
      { status: :success }
    end

    controller.send(
      :establish_signed_in_session!,
      user,
      pt: nil,
      ri: "jp",
      auth_method: "social",
      audit_context: { auth_method: "oauth", provider: "google" },
    )

    assert_equal user, captured.first
    assert_equal(
      { auth_method: "oauth", provider: "google" },
      captured.last[:audit_context],
    )
  end

  private

  # Build a minimal controller-like object that includes AuthenticationBase for testing
  def build_test_controller
    mfa_intercept_controller_class.new
  end

  def mfa_intercept_controller_class
    Class.new do
      include CommonRedirect
      include AuthenticationBase

      attr_accessor :session

      define_method(:initialize) { @session = {} }
      define_method(:resource_class) { ::Client }
      define_method(:token_class) { ClientToken }
      define_method(:audit_class) { ::ClientChronicle }
      define_method(:resource_type) { "user" }
      define_method(:resource_foreign_key) { :user_id }
      define_method(:test_header_key) { "X-TEST-CURRENT-USER" }
      define_method(:sign_in_url_with_pt) { |_rt| "/sign/in" }
      define_method(:am_i_user?) { true }
      define_method(:am_i_staff?) { false }
      define_method(:am_i_owner?) { false }
      define_method(:respond_to?) do |name, include_private = false|
        return true if name == :sign_app_sign_in_mfa_path

        super(name, include_private)
      end
      define_method(:sign_app_sign_in_mfa_path) do |ri: nil|
        ri ? "/sign/in/mfa?ri=#{ri}" : "/sign/in/mfa"
      end
    end
  end
end

# DAMP local route helper aliases for former shared test support.
class Auth::MfaInterceptUnitTest
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
