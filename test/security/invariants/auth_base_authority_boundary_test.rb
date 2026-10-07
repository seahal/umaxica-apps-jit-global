# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthBaseAuthorityBoundaryTest < ActiveSupport::TestCase
  AUTH_APPLICATION_CONTROLLERS = [
    Auth::App::ApplicationController,
    Auth::Com::ApplicationController,
    Auth::Org::ApplicationController,
  ].freeze

  BASE_AUTHORITY_CONTROLLERS = [
    Base::App::AuthorityController,
    Base::Com::AuthorityController,
    Base::Org::AuthorityController,
  ].freeze

  AUTH_SIGN_OUT_CONTROLLERS = [
    Auth::App::Sign::OutsController,
    Auth::Com::Sign::OutsController,
    Auth::Org::Sign::OutsController,
  ].freeze

  test "Auth and Base Authority controllers do not inherit browser RP lifecycle" do
    (AUTH_APPLICATION_CONTROLLERS + BASE_AUTHORITY_CONTROLLERS).each do |controller|
      assert_not_includes controller.ancestors, OidcSsoInitiator, controller.name
      assert_not_includes controller.ancestors, BrowserRpAuthentication, controller.name
      assert_not_includes controller.ancestors, BrowserRpSafeRequestRefresh, controller.name
      assert_not_includes controller.ancestors, BrowserRpUnsafeRequestRefresh, controller.name
      assert_not controller.private_method_defined?(:oidc_client_id), controller.name
    end
  end

  test "Base self-RP controllers retain browser RP lifecycle and inherit no root authentication" do
    [Base::App::ApplicationController, Base::Com::ApplicationController,
     Base::Org::ApplicationController,].each do |controller|
      assert_includes controller.ancestors, BrowserRpAuthentication, controller.name
      assert_not_includes controller.ancestors, AuthenticationBase, controller.name
    end
  end

  test "Auth sign-out controllers do not act as OIDC RPs" do
    AUTH_SIGN_OUT_CONTROLLERS.each do |controller|
      assert_not_includes controller.ancestors, OidcRpLogoutLauncher, controller.name
      assert_not controller.private_method_defined?(:oidc_client_id), controller.name
    end
  end
end
