# frozen_string_literal: true

require "test_helper"

class ProtocolControllerCsrfBoundaryTest < ActiveSupport::TestCase
  PROTOCOL_CONTROLLERS = [
    Base::App::Oauth::TokensController,
    Auth::App::Apple::NotificationsController,
    Core::App::Oidc::Backchannel::LogoutsController,
    Core::Com::Oidc::Backchannel::LogoutsController,
    Core::Org::Oidc::Backchannel::LogoutsController,
  ].freeze

  test "token and signed-message protocol endpoints do not load browser session CSRF protection" do
    PROTOCOL_CONTROLLERS.each do |controller|
      assert_operator controller, :<, ActionController::API, controller.name
      assert_not_operator controller, :<, ActionController::RequestForgeryProtection, controller.name
      assert_not_includes controller._process_action_callbacks.map(&:filter),
                          :verify_authenticity_token,
                          controller.name
    end
  end
end
