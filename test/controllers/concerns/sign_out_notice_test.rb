# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignOutNoticeTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    class << self
      def helper_method(*)
      end
    end

    include SignOutNotice

    attr_reader :session, :response, :request, :params

    def initialize(session = {}, params = {})
      @session = session
      @response = Struct.new(:headers).new({})
      @request = Struct.new(:params).new({})
      @params = ActionController::Parameters.new(params)
    end

    def current_resource
      nil
    end

    def current_session_public_id
      nil
    end

    def current_sign_out_access_expires_at
      nil
    end

    def controller_path
      "auth/app/sign_outs"
    end

    def new_auth_app_sign_out_path(**options) = [__method__, options]

    def new_auth_app_sign_out_url(**options) = [__method__, options]

    def edit_auth_app_sign_out_url(**options) = [__method__, options]

    def auth_app_sign_out_path(**options) = [__method__, options]

    def auth_app_sign_out_url(**options) = [__method__, options]

    def auth_app_root_url(**options) = [__method__, options]
  end

  test "stores and consumes a notice once" do
    harness = Harness.new
    harness.send(:prepare_sign_out_completion_notice!, state: "opaque-state")
    harness.send(:issue_sign_out_notice!)

    notice = harness.send(:consume_sign_out_notice)

    assert notice
    assert_equal "opaque-state", notice[:state]
    assert_nil harness.session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY]
    assert_nil harness.send(:consume_sign_out_notice)
  end

  test "rejects non-string session markers without restoring them" do
    harness = Harness.new(
      SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY => {
        "expires_at" => 1.minute.ago.iso8601,
        "access_expires_at" => nil,
        "sid" => "sign_out_notice",
      },
    )

    assert_nil harness.send(:consume_sign_out_notice)
    assert_nil harness.session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY]
  end

  test "reports completion notice presence when an opaque notice id is present" do
    harness = Harness.new(SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY => "opaque-notice-id")

    assert_predicate harness, :sign_out_completion_notice_present?
    assert_not_predicate harness, :sign_out_active_context_present?
  end

  test "builds every sign out URL variant with preserved route state" do
    harness = Harness.new({}, { ri: "return-id", logout_challenge: "challenge" })
    expected_options = { ri: "return-id", logout_challenge: "challenge", host: "app.example.test" }

    assert_equal [:new_auth_app_sign_out_path, expected_options],
                 harness.send(:sign_out_new_path, host: "app.example.test", ignored: nil)
    assert_equal [:new_auth_app_sign_out_url, expected_options],
                 harness.send(:sign_out_new_url, host: "app.example.test", ignored: nil)
    assert_equal [:edit_auth_app_sign_out_url, expected_options],
                 harness.send(:sign_out_edit_url, host: "app.example.test", ignored: nil)
    assert_equal [:auth_app_sign_out_path, expected_options],
                 harness.send(:sign_out_post_path, host: "app.example.test", ignored: nil)
    assert_equal [:auth_app_sign_out_url, expected_options],
                 harness.send(:sign_out_post_url, host: "app.example.test", ignored: nil)
    assert_equal [:auth_app_sign_out_url, expected_options],
                 harness.send(:sign_out_complete_url, host: "app.example.test", ignored: nil)
    assert_equal [:auth_app_root_url, expected_options],
                 harness.send(:sign_out_home_url, host: "app.example.test", ignored: nil)
    assert_equal [:auth_app_sign_out_path, expected_options.except(:host)],
                 harness.send(:sign_out_confirmation_form_path)
  end
end
