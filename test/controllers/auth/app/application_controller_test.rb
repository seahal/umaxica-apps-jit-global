# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Auth::App
  class ApplicationControllerTest < ActionDispatch::IntegrationTest
    test "includes expected concerns" do
      controller = ApplicationController.new

      assert_includes controller.class, ::AuthenticationClient
      assert_includes controller.class, ::AuthorizationClient
      assert_includes controller.class, ::VerificationClient
    end

    test "includes expected concerns 2nd" do
      controller = ApplicationController.new

      assert_includes controller.class, RateLimit
      assert_includes controller.class, ::PreferenceGlobal
    end

    test "application controller defaults to deny all authentication mode" do
      assert_equal :deny_all, ApplicationController.authentication_mode_for(:index)

      rules = ApplicationController.local_authentication_mode_rules

      assert_empty rules
    end

    test "application controller preserves authentication callback order" do
      callbacks = ApplicationController._process_action_callbacks
      before_filters = callbacks.select { |callback| callback.kind == :before }.map(&:filter)

      expected_before_filters = %i(
        set_current_context
        reset_flash
        set_preferences_cookie
        resolve_param_context
        set_region
        transparent_refresh_access_token
        set_current_actor
        apply_localization_preferences
        set_color_theme
        enforce_withdrawal_gate!
        enforce_verification_if_required
        enforce_access_policy!
        set_current_observability
      )

      expected_before_filters.each_cons(2) do |first, second|
        assert_operator before_filters.index(first), :<, before_filters.index(second)
      end
    end

    test "app surface does not define guest controller boundaries" do
      assert_not ::Auth::App.const_defined?(:GuestController, false)
      assert_not ::Auth::App::Sign::In.const_defined?(:GuestController, false)
      assert_not ::Auth::App::Sign::Up.const_defined?(:GuestController, false)
    end

    test "sign-in controllers declare guest-only policy on concrete controller" do
      assert_equal :guest, Auth::App::Sign::In::EmailsController.authentication_mode_for(:new)
    end

    test "sign-up controllers declare guest-only policy on concrete controller" do
      assert_equal :guest, Auth::App::Sign::Up::EmailsController.authentication_mode_for(:new)
    end

    test "email sign-in controller overrides guest-only response" do
      rules = Auth::App::Sign::In::EmailsController.local_authentication_mode_rules

      assert_equal :guest, rules.last[:mode]
      assert_equal :bad_request, rules.last[:options][:status]
      assert_equal(
        I18n.t("sign.app.authentication.email.new.you_have_already_logged_in"),
        rules.last[:options][:message],
      )
      assert rules.last[:options][:no_redirect]
    end

    test "authenticate_client! allows logged in clients" do
      controller = ApplicationController.new
      controller.define_singleton_method(:logged_in?) { true }
      controller.define_singleton_method(:respond_to) { |_block| nil }

      # Should not raise or call respond_to
      assert_nothing_raised do
        controller.send(:authenticate_client!)
      end
    end
  end
end
