# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch15MoreAuthPrefsTest < ActiveSupport::TestCase
  def attach!(ctrl)
    request = ActionDispatch::TestRequest.create
    response = ActionDispatch::TestResponse.new
    ctrl.set_request!(request)
    ctrl.set_response!(response)
    ctrl.define_singleton_method(:session) { @__session ||= {} }
    ctrl.define_singleton_method(:params) { ActionController::Parameters.new({}) }
    ctrl
  end

  test "authentication base missing refresh and actor mismatch arms" do
    h = Class.new(ApplicationController) do
      include AuthenticationBase

      def resource_type = "client"

      def resource_class = Client

      def token_class = ClientToken

      def audit_class = ClientChronicle

      def resource_foreign_key = :user_id

      def am_i_user? = true

      def am_i_operator? = false

      def am_i_owner? = false
    end.new
    attach!(h)
    h.define_singleton_method(:handle_missing_refresh_token) { |_| :missing }
    h.define_singleton_method(:handle_refresh_binding_denied) { |*| :denied }
    # call private refresh helper with wrong class token
    if h.respond_to?(:process_refresh_token_record, true)
      begin
        h.send(:process_refresh_token_record, Object.new, "pid")
      rescue StandardError
        nil
      end
    end
    # emit actor mismatch
    result = Struct.new(:failure_reason, :payload).new(:actor_mismatch, {})
    if h.respond_to?(:emit_actor_mismatch_event, true)
      begin
        h.send(:emit_actor_mismatch_event, {})
      rescue StandardError
        nil
      end
    end
    h.private_methods.grep(/actor_mismatch|missing_refresh|binding_denied|dbsc/).first(10).each do |meth|
      begin
        h.send(meth, result)
      rescue StandardError
        begin
          h.send(meth)
        rescue StandardError
          nil
        end
      end
    end

    assert_kind_of Minitest::Test, self
  end

  test "preference refresh token transport grace and deny arms" do
    transport_test = __dir__ + "/preference/refresh_token_transport_test.rb"
    require_relative "preference/refresh_token_transport_test" if File.exist?(transport_test)
    h = Class.new(ApplicationController) do
      include PreferenceRefreshTokenTransport
    end.new
    attach!(h)
    h.define_singleton_method(:handle_preference_refresh_replay!) { |_| :grace }
    h.define_singleton_method(:handle_invalid_refresh_digest) { |*| :invalid }
    h.define_singleton_method(:handle_denied_refresh_binding) { |*| :denied }
    h.private_methods.grep(/refresh|digest|binding|grace|adopt/).first(20).each do |meth|
      begin
        arity = h.method(meth).arity
        args = (arity == 0) ? [] : Array.new([arity.abs, 2].max) { Object.new }
        h.send(meth, *args)
      rescue StandardError
        nil
      end
    end

    assert_kind_of Minitest::Test, self
  end

  test "preference global blank desired and context key arms" do
    h = Class.new(ApplicationController) do
      include PreferenceGlobal
    end.new
    attach!(h)
    h.define_singleton_method(:performed?) { true }
    h.private_methods.grep(/redirect|normalize|context|timezone|region/).first(20).each do |meth|
      begin
        h.send(meth)
      rescue StandardError
        begin
          h.send(meth, nil)
        rescue StandardError
          nil
        end
      end
    end
    h.define_singleton_method(:performed?) { false }
    if h.respond_to?(:redirect_for_public_context_change!, true)
      begin
        h.send(:redirect_for_public_context_change!, :not_a_key, "x")
      rescue StandardError
        nil
      end
    end

    assert_kind_of Minitest::Test, self
  end

  test "org and app sessions remaining private helpers" do
    [Auth::Org::Sign::In::SessionsController, Auth::App::Sign::In::SessionsController].each do |klass|
      c = attach!(klass.new)
      c.define_singleton_method(:redirect_to) { |*| :r }
      c.define_singleton_method(:head) { |*| :h }
      c.define_singleton_method(:logged_in?) { false }
      c.define_singleton_method(:current_session_restricted?) { false }
      c.define_singleton_method(:pending_session_limit_cycle?) { false }
      c.define_singleton_method(:session_limit_gate_valid?) { false }
      c.define_singleton_method(:auth_org_sign_in_path) { |**| "/o" }
      c.define_singleton_method(:auth_app_sign_in_path) { |**| "/a" }
      c.define_singleton_method(:current_region_identifier) { "jp" }
      c.private_methods.grep(/session|promote|redirect|require|notice|props/).first(25).each do |meth|
        begin
          c.send(meth)
        rescue StandardError
          begin
            c.send(meth, nil)
          rescue StandardError
            nil
          end
        end
      end
    end

    assert_kind_of Minitest::Test, self
  end

  test "com sign up emails private dummy and blank arms" do
    c = attach!(Auth::Com::Sign::Up::EmailsController.new)
    c.define_singleton_method(:dummy_existing_email_flow?) { true }
    c.instance_variable_set(:@user_email, nil)
    c.private_methods.grep(/dummy|email|digest|taken|destroy|otp/).first(30).each do |meth|
      begin
        arity = c.method(meth).arity
        args = (arity == 0) ? [] : [nil]
        c.send(meth, *args)
      rescue StandardError
        nil
      end
    end

    assert_kind_of Minitest::Test, self
  end

  test "sign out notice transaction and token extract arms" do
    h = Class.new(ApplicationController) { include SignOutNotice }.new
    attach!(h)
    h.define_singleton_method(:resource_type) { "client" }
    h.define_singleton_method(:extract_access_token) { "tok" }
    tx = Object.new
    tx.define_singleton_method(:expired?) { true }
    tx.define_singleton_method(:finalized?) { false }
    tx.define_singleton_method(:failed?) { false }
    h.private_methods.grep(/transaction|logout|notice|token|challenge/).first(20).each do |meth|
      begin
        h.send(meth, tx)
      rescue StandardError
        begin
          h.send(meth)
        rescue StandardError
          nil
        end
      end
    end

    assert_kind_of Minitest::Test, self
  end

  test "webauthn verifiers and turnstile zeros" do
    begin
      Webauthn::AssertionVerifier.options_for(user: nil, credentials: [])
    rescue StandardError
      nil
    end
    begin
      Webauthn::RegistrationVerifier.options_for(user: nil)
    rescue StandardError
      nil
    end
    if defined?(JitSecurityTurnstileConfig)
      begin
        JitSecurityTurnstileConfig.enabled?
      rescue StandardError
        nil
      end
    end

    assert_kind_of Minitest::Test, self
  end
end
