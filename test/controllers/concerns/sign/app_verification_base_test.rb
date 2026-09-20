# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignAppVerificationBaseTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :clients

  ClientStruct = Struct.new(:id, :public_id, :client_passkeys, :client_totp_credentials)

  class Harness
    class << self
      def before_action(*) = nil

      def helper_method(*) = nil

      def declare_authentication_mode!(*, **) = nil
    end

    def verification_model = nil

    def verification_audit_event_class = nil

    def verification_audit_level_class = nil

    def verification_success_event_id = nil

    def verification_success_notice_key = nil

    def verification_success_fallback_path = nil

    def verification_activity_model = nil

    def verification_passkey_model = nil

    def verification_no_passkey_i18n_key = nil

    def verification_unavailable_redirect_path = "/verification?ri=jp"

    include SignVerificationStepUpSessionStore
    include SignVerificationStepUpLifecycle
    include SignAppVerificationBase

    attr_accessor :user, :user_token, :params_hash, :redirect_args, :hotp_result, :session_hash

    def initialize(user:, user_token: nil)
      @user = user
      @user_token = user_token
      @params_hash = {}
      @hotp_result = true
      @session_hash = {}
    end

    def current_client = user

    def actor_token = user_token

    def current_session_token = user_token

    def params = ActionController::Parameters.new(params_hash)

    def session = session_hash

    def auth_app_verification_path(params = {})
      "/verification?#{params.to_query}"
    end

    def auth_app_settings_path(params = {})
      "/settings?#{params.to_query}"
    end

    def signed_pt_to_safe_path(value)
      value.to_s.start_with?("/") ? value.to_s : nil
    end

    def issue_step_up_pt(value)
      "signed--#{value}"
    end

    def auth_app_root_path(params = {})
      "/?#{params.to_query}"
    end

    def current_step_up_session
      user_token&.step_up_session
    end

    def start_step_up_session!(scope:, pt_param:)
      SignVerificationStepUpSessionStore.instance_method(:start_step_up_session!).bind_call(
        self,
        scope: scope,
        pt_param: pt_param,
      )
    end

    def safe_redirect_to(*args, **kwargs)
      self.redirect_args = [args, kwargs]
    end

    def verify_hotp_code(secret_credential:, counter:, pass_code:)
      hotp_result && secret_credential == "secret_credential" && counter == 1 && pass_code == "123456"
    end

    def app_call(method_name, ...)
      SignAppVerificationBase.instance_method(method_name).bind_call(self, ...)
    end

    def clear_step_up_state!
      app_call(:clear_step_up_state!)
    end

    def restore_step_up_session_from_params!
      app_call(:restore_step_up_session_from_params!)
    end

    def valid_step_up_session?(rs)
      app_call(:valid_step_up_session?, rs)
    end
  end

  setup do
    @previous_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @previous_cache_store
  end

  test "email otp session active and nonce helpers use step_up session session state" do
    user = clients(:one)
    token = ClientToken.create!(user: user)
    harness = Harness.new(user: user, user_token: token)

    assert_not harness.app_call(:email_otp_session_active?)

    create_user_step_up_session(user_token: token)
    harness.app_call(
      :write_email_otp_session_data!,
      { "otp_digest" => harness.app_call(:email_otp_digest, "123456") },
    )

    assert harness.app_call(:email_otp_session_active?)

    harness.clear_step_up_state!

    assert_not harness.app_call(:email_otp_session_active?)

    nonce = harness.app_call(:ensure_email_nonce!)

    assert_predicate nonce, :present?
    assert_equal nonce, harness.app_call(:ensure_email_nonce!)
    assert_equal "settings_email", harness.app_call(:current_step_up_scope)
    assert_match(/--/, harness.app_call(:current_step_up_pt_param))
  end

  test "step_up session validation and restore from params" do
    user = clients(:one)
    token = ClientToken.create!(user: user)
    other_token = ClientToken.create!(user: user)
    harness = Harness.new(user: user, user_token: token)
    valid_session = create_user_step_up_session(user_token: token)

    assert harness.app_call(:valid_step_up_session?, valid_session)
    assert_not harness.app_call(
      :valid_step_up_session?, valid_session.dup.tap { |rs|
                                 rs.user_token_id = other_token.id
                               },
    )
    assert_not harness.app_call(:valid_step_up_session?, valid_session.dup.tap { |rs| rs.discarded_at = 1.minute.ago })
    assert_not harness.app_call(:valid_step_up_session?, valid_session.dup.tap { |rs| rs.scope = "" })
    assert_not harness.app_call(:valid_step_up_session?, valid_session.dup.tap { |rs| rs.return_to = "" })

    return_to = "/settings/emails"
    harness.params_hash = { scope: "settings_email", return_to: return_to }

    assert_not harness.app_call(:restore_step_up_session_from_params!)

    harness.params_hash = {}

    assert_not harness.app_call(:restore_step_up_session_from_params!)
  end

  test "invalid step_up session redirects and clears session state" do
    user = clients(:one)
    token = ClientToken.create!(user: user)
    harness = Harness.new(user: user, user_token: token)
    harness.params_hash = { ri: "jp" }
    create_user_step_up_session(user_token: token)
    harness.app_call(
      :write_email_otp_session_data!,
      { "otp_digest" => harness.app_call(:email_otp_digest, "123456") },
    )

    assert_not harness.app_call(:handle_invalid_step_up_session!)
    assert_nil harness.session[:sign_app_step_up_email_otp]
    assert_match "/settings?", harness.redirect_args.first.first
  end

  test "app verification exposes user specific models and values" do
    passkey = Struct.new(:user_id).new(7)
    user = ClientStruct.new(7, "user-public-id", [:passkey], [])
    harness = Harness.new(user: user)
    harness.params_hash = { ri: "jp" }

    assert_equal :user_token_id, harness.app_call(:step_up_session_token_foreign_key)
    assert_equal "/verification?ri=jp", harness.app_call(:verification_unavailable_redirect_path)
    assert_equal ClientVerification, harness.app_call(:verification_model)
    assert_equal ClientChronicleEvent::STEP_UP_VERIFIED, harness.app_call(:verification_success_event_id)
    assert_equal "sign.app.verification.success.complete", harness.app_call(:verification_success_notice_key)
    assert_equal "/verification?ri=jp", harness.app_call(:verification_success_fallback_path)
    assert_equal ClientChronicleEvent, harness.app_call(:verification_audit_event_class)
    assert_equal ClientChronicleLevel, harness.app_call(:verification_audit_level_class)
    assert_equal ClientChronicleLevel::NOTHING, harness.app_call(:verification_default_activity_level_id)
    assert_equal ClientChronicle, harness.app_call(:verification_activity_model)
    assert_equal user, harness.app_call(:current_verification_actor)
    assert_equal "Client", harness.app_call(:verification_actor_type)
    assert_equal [:passkey], harness.app_call(:verification_passkeys_scope)
    assert_equal ClientPasskey, harness.app_call(:verification_passkey_model)
    assert harness.app_call(:passkey_actor_matches?, passkey)
    assert_equal "sign.app.verification.errors.no_passkey", harness.app_call(:verification_no_passkey_i18n_key)
  end

  test "verify_email_otp handles invalid missing expired wrong and valid codes" do
    user = clients(:one)
    token = ClientToken.create!(user: user)
    harness = Harness.new(user: user, user_token: token)
    step_up_session = create_user_step_up_session(user_token: token)

    harness.params_hash = { verification: { code: "abc" } }

    assert_not harness.app_call(:verify_email_otp!)
    assert_equal ["確認コードが不正です"], harness.instance_variable_get(:@verification_errors)

    harness.params_hash = { verification: { code: "123456" } }

    assert_not harness.app_call(:verify_email_otp!)
    assert_equal ["確認コードの再送信が必要です"], harness.instance_variable_get(:@verification_errors)

    harness.app_call(
      :write_email_otp_session_data!,
      { "otp_digest" => harness.app_call(:email_otp_digest, "123456") },
    )
    step_up_session.update_columns(discarded_at: 1.minute.ago, purged_at: 1.minute.ago)

    assert_not harness.app_call(:verify_email_otp!)
    assert_equal ["確認コードの有効期限が切れました"], harness.instance_variable_get(:@verification_errors)

    step_up_session.update!(discarded_at: 5.minutes.from_now, purged_at: 5.minutes.from_now)
    harness.app_call(
      :write_email_otp_session_data!,
      { "otp_digest" => harness.app_call(:email_otp_digest, "654321") },
    )

    assert_not harness.app_call(:verify_email_otp!)
    assert_equal ["確認コードが正しくありません"], harness.instance_variable_get(:@verification_errors)

    harness.app_call(
      :write_email_otp_session_data!,
      { "otp_digest" => harness.app_call(:email_otp_digest, "123456") },
    )

    assert harness.app_call(:verify_email_otp!)
  end

  private

  def create_user_step_up_session(user_token:, scope: "settings_email", return_to: "/settings/emails")
    ClientStepUpSession.create!(
      user_token: user_token,
      scope: scope,
      return_to: return_to,
      method: nil,
      status: "PENDING",
      attempt_count: 0,
      discarded_at: 5.minutes.from_now,
      purged_at: 5.minutes.from_now,
    )
  end
end

# DAMP local route helper aliases for former shared test support.
class SignAppVerificationBaseTest
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
