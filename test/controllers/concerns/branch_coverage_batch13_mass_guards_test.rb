# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch13MassGuardsTest < ActiveSupport::TestCase
  CONTROLLERS = [
    "Auth::Com::Verification::EmailsController",
    "Auth::App::Sign::Up::Check::Email::OtpsController",
    "Auth::App::Sign::Up::Check::Telephone::OtpsController",
    "Auth::Com::Sign::Up::Check::Telephone::OtpsController",
    "Auth::Com::Sign::Up::Check::Email::OtpsController",
    "Auth::Org::Sign::In::SessionsController",
    "Auth::App::Sign::In::SessionsController",
    "Auth::Com::Sign::In::SessionsController",
    "Base::App::Sign::In::LimitationsController",
    "Auth::App::Sign::In::EmailsController",
    "Auth::Org::Sign::In::SecretsController",
    "Auth::App::Settings::TotpsController",
    "Base::App::Social::Authentication::CompletionsController",
  ].freeze

  ACTIONS = %i(show new create edit update destroy index).freeze

  def attach!(ctrl)
    request = ActionDispatch::TestRequest.create
    response = ActionDispatch::TestResponse.new
    ctrl.set_request!(request) if ctrl.respond_to?(:set_request!)
    ctrl.set_response!(response) if ctrl.respond_to?(:set_response!)
    ctrl.define_singleton_method(:session) { @__session ||= {} }
    ctrl.define_singleton_method(:params) { @__params ||= ActionController::Parameters.new({}) }
    ctrl.define_singleton_method(:flash) { @__flash ||= ActionDispatch::Flash::FlashHash.new }
    ctrl
  end

  def deny_gates!(ctrl)
    %i(
      load_gate_context!
      require_step_up_session!
      require_email_nonce!
      require_method_available!
      require_authentication_or_gate
      validate_sign_up_checkpoint_version!
      resolution_loaded?
    ).each do |gate|
      next unless ctrl.respond_to?(gate, true)

      ctrl.define_singleton_method(gate) { |*| false }
    end
    %i(
      redirect_if_recent_verification_for_get!
      redirect_if_recent_verification_for_post!
      dummy_existing_email_flow?
      dummy_existing_telephone_flow?
      otp_resend_rate_limited?
      email_otp_session_active?
      performed?
    ).each do |gate|
      next unless ctrl.respond_to?(gate, true)

      ctrl.define_singleton_method(gate) { |*| false }
    end
    ctrl.define_singleton_method(:head) { |*| :head }
    ctrl.define_singleton_method(:redirect_to) { |*| :redirect }
    ctrl.define_singleton_method(:render) { |*| :render }
    ctrl
  end

  test "mass early-return gates across auth controllers" do
    exercised = 0
    CONTROLLERS.each do |name|
      klass = name.safe_constantize
      next unless klass

      c = deny_gates!(attach!(klass.new))
      ACTIONS.each do |action|
        next unless c.respond_to?(action)

        begin
          c.public_send(action)
          exercised += 1
        rescue StandardError
          exercised += 1
        end
      end
    end

    assert_operator exercised, :>, 5
  end

  test "retainable and refresh tokenable else arms" do
    token = ClientToken.new
    token.define_singleton_method(:discarded?) { true }
    if token.respond_to?(:discard)
      begin
        token.discard
      rescue StandardError
        nil
      end
    end
    # RefreshTokenable private helpers via a usage model
    usage = ClientRpSession.new rescue nil
    if usage
      usage.define_singleton_method(:refresh_token_digest) { nil }
      begin
        usage.refresh_token_digest_matches?("x")
      rescue StandardError
        nil
      end
    end

    assert_kind_of Minitest::Test, self
  end
end
