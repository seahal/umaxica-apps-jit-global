# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignUpSessionStateTest < ActiveSupport::TestCase
  def make_session
    {}
  end

  test "for creates instance with app surface" do
    state = SignUpSessionState.for({}, surface: :app)

    assert_instance_of SignUpSessionState, state
  end

  test "for raises for unsupported surface" do
    assert_raises(ArgumentError) do
      SignUpSessionState.for({}, surface: :org)
    end
  end

  test "cycle_payload getter and setter" do
    session = {}
    state = SignUpSessionState.for(session, surface: :app)

    assert_nil state.cycle_payload

    state.cycle_payload = { "key" => "value" }

    assert_equal({ "key" => "value" }, state.cycle_payload)
    assert_equal({ "key" => "value" }, session[:app_sign_up_flow_locator])

    state.cycle_payload = nil

    assert_nil state.cycle_payload
    assert_not_includes session, :app_sign_up_flow_locator
  end

  test "sequence_id getter and setter" do
    session = {}
    state = SignUpSessionState.for(session, surface: :app)

    assert_nil state.sequence_id

    state.sequence_id = "seq-123"

    assert_equal "seq-123", state.sequence_id
    assert_equal "seq-123", session[:auth_app_up_sequence_id]

    state.sequence_id = nil

    assert_nil state.sequence_id
  end

  test "telephone_otp returns empty hash by default" do
    state = SignUpSessionState.for({}, surface: :app)

    assert_equal({}, state.telephone_otp)
  end

  test "telephone_otp getter and setter" do
    session = {}
    state = SignUpSessionState.for(session, surface: :app)

    state.telephone_otp = { "phone" => "123" }

    assert_equal({ "phone" => "123" }, state.telephone_otp)

    state.telephone_otp = nil

    assert_equal({}, state.telephone_otp)
    assert_not_includes session, :user_telephone_registration
  end

  test "existing_email getter and setter" do
    session = {}
    state = SignUpSessionState.for(session, surface: :app)

    assert_nil state.existing_email

    state.existing_email = "test@example.com"

    assert_equal "test@example.com", state.existing_email

    state.existing_email = nil

    assert_nil state.existing_email
  end

  test "existing_email_skip_otp flag" do
    state = SignUpSessionState.for({}, surface: :app)

    assert_not_predicate state, :existing_email_skip_otp?

    state.existing_email_skip_otp = true

    assert_predicate state, :existing_email_skip_otp?

    state.existing_email_skip_otp = false

    assert_not_predicate state, :existing_email_skip_otp?

    state.existing_email_skip_otp = nil

    assert_not_predicate state, :existing_email_skip_otp?
  end

  test "clear_email_flow! removes email keys" do
    session = {}
    state = SignUpSessionState.for(session, surface: :app)
    state.existing_email = "test@example.com"
    state.existing_email_skip_otp = true

    state.clear_email_flow!

    assert_nil state.existing_email
    assert_not_predicate state, :existing_email_skip_otp?
  end

  test "clear_telephone_flow! removes telephone key" do
    session = {}
    state = SignUpSessionState.for(session, surface: :app)
    state.telephone_otp = { "phone" => "123" }

    state.clear_telephone_flow!

    assert_equal({}, state.telephone_otp)
  end

  test "clear_all! removes all keys" do
    session = {}
    state = SignUpSessionState.for(session, surface: :app)
    state.cycle_payload = { "key" => "value" }
    state.sequence_id = "seq-123"
    state.telephone_otp = { "phone" => "123" }

    state.clear_all!

    assert_nil state.cycle_payload
    assert_nil state.sequence_id
    assert_equal({}, state.telephone_otp)
  end

  test "state writes only app surface keys" do
    session = {}
    state = SignUpSessionState.for(session, surface: :app)

    state.cycle_payload = "payload"

    assert_equal "payload", session[:app_sign_up_flow_locator]

    state.sequence_id = "seq-app"

    assert_equal "seq-app", session[:auth_app_up_sequence_id]

    state.telephone_otp = { "phone" => "456" }

    assert_equal({ "phone" => "456" }, session[:user_telephone_registration])
  end
end

# DAMP local route helper aliases for former shared test support.
class SignUpSessionStateTest
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
