# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignEmailRegistrationFlowTest < ActiveSupport::TestCase
  class Harness
    class << self
      def before_action(*) = nil

      def skip_before_action(*) = nil
    end

    include SignEmailRegistrable
    include SignEmailRegistrationFlow
    include EnforcementIdentifierGate

    attr_accessor :session_hash, :flash_hash, :reset_called, :target_user, :params_hash, :render_args, :redirect_args

    def initialize
      @session_hash = {}
      @flash_hash = {}
      @reset_called = false
      @params_hash = {}
    end

    def session = session_hash

    def flash = flash_hash

    def params = ActionController::Parameters.new(params_hash)

    def safe_internal_path(path)
      (path.to_s.start_with?("/") && !path.to_s.start_with?("//")) ? path : nil
    end

    def signed_pt_token(value)
      safe_path = safe_internal_path(value)
      safe_path ? "signed:#{safe_path}" : nil
    end

    def path_from_signed_pt(token)
      token.to_s.start_with?("signed:") ? token.delete_prefix("signed:") : nil
    end

    def build_notice_params(message, _session_key = nil)
      { notice: message, pt: signed_pt_token("/settings/emails") }
    end

    def reset_email_flow!
      self.reset_called = true
    end

    def t(...)
      I18n.t(...)
    end

    def new_email_registration_path(params = {})
      "/emails/new?#{params.to_query}"
    end

    def auth_app_settings_emails_url(**params)
      query = params.to_query
      query.present? ? "/settings/emails?#{query}" : "/settings/emails"
    end

    def cross_host_redirect_allowed?
      false
    end

    def email_registration_target_user
      target_user
    end

    def verify_email_registration_turnstile!(...)
      true
    end

    def initiate_email_verification!(*)
      false
    end

    def render(*args, **kwargs)
      self.render_args = [*args, kwargs]
    end

    def redirect_to(*args, **kwargs)
      self.redirect_args = [*args, kwargs].reject(&:empty?)
    end
  end

  test "create renders new when verification cannot be initiated" do
    harness = Harness.new
    harness.params_hash = {
      user_email: {
        raw_address: "failed-registration@example.com",
        confirm_policy: "1",
      },
    }

    harness.create

    assert_equal [:new, { status: :unprocessable_content }], harness.render_args
  end

  test "update redirects to new registration path when session is invalid" do
    harness = Harness.new
    harness.params_hash = { user_email: { pass_code: "123456" } }

    harness.update

    assert_predicate harness, :reset_called
    assert_equal ["/emails/new?pt=signed%3A%2Fsettings%2Femails"], harness.redirect_args
  end

  test "update renders the edit screen when turnstile stealth validation fails" do
    harness = Harness.new
    flash = Object.new
    now_store = {}
    flash.define_singleton_method(:now) { now_store }
    flash.define_singleton_method(:[]=) { |key, value|
      instance_variable_set(:@store, (instance_variable_get(:@store) || {}).merge(key => value))
    }
    flash.define_singleton_method(:[]) { |key| (instance_variable_get(:@store) || {})[key] }
    harness.flash_hash = flash
    pending = ClientEmail.new
    pending.define_singleton_method(:otp_expired?) { false }
    pending.user_email_status_id = ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP
    harness.define_singleton_method(:current_registration_email) { pending }
    harness.define_singleton_method(:valid_registration_email_session?) { true }
    harness.define_singleton_method(:cloudflare_turnstile_stealth_validation) { { "success" => false } }

    harness.update

    assert_equal [:edit, { status: :unprocessable_content }], harness.render_args
    assert_equal I18n.t("turnstile_error"), now_store[:alert]
  end

  test "resend redirects away unless the registration email is resendable" do
    harness = Harness.new

    harness.resend

    assert_predicate harness, :reset_called
    assert_equal ["/emails/new?pt=signed%3A%2Fsettings%2Femails"], harness.redirect_args
  end

  test "resend redirects with a too-soon notice while the otp cooldown is active" do
    harness = Harness.new
    pending = ClientEmail.new
    pending.define_singleton_method(:otp_expired?) { false }
    pending.define_singleton_method(:locked?) { false }
    pending.define_singleton_method(:otp_cooldown_active?) { true }
    pending.user_email_status_id = ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP
    harness.define_singleton_method(:current_registration_email) { pending }
    harness.define_singleton_method(:after_email_registration_started_path) { |params = {}|
      "/emails/edit?#{params.to_query}"
    }
    harness.define_singleton_method(:build_redirect_params) { |key, message, _session_key| { key => message } }

    harness.resend

    assert_match %r{\A/emails/edit\?}, harness.redirect_args.first
    assert_equal I18n.t("otp.resend.too_soon"), harness.flash_hash[:alert]
  end

  test "resend generates an otp and redirects with a sent notice" do
    harness = Harness.new
    pending = ClientEmail.new
    pending.define_singleton_method(:otp_expired?) { false }
    pending.define_singleton_method(:locked?) { false }
    pending.define_singleton_method(:otp_cooldown_active?) { false }
    pending.user_email_status_id = ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP
    harness.define_singleton_method(:current_registration_email) { pending }
    generated = []
    sent = []
    harness.define_singleton_method(:generate_otp_for) { |email| generated << email; "654321" }
    harness.define_singleton_method(:send_verification_email) { |code| sent << code }
    harness.define_singleton_method(:after_email_registration_started_path) { |params = {}|
      "/emails/edit?#{params.to_query}"
    }
    harness.define_singleton_method(:build_redirect_params) { |key, message, _session_key| { key => message } }

    harness.resend

    assert_equal [pending], generated
    assert_equal ["654321"], sent
    assert_equal I18n.t("otp.resend.sent"), harness.flash_hash[:notice]
  end
end
