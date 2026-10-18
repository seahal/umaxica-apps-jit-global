# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::Omniauth::OmniauthCallbacksControllerTest < ActiveSupport::TestCase
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file exercises real controller actions, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  test "callback routes accept GET only" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    google_route = Rails.application.routes.recognize_path(
      "http://#{host}/social/google/callback",
      method: :get,
    )
    apple_get_route = Rails.application.routes.recognize_path(
      "http://#{host}/social/apple/callback",
      method: :get,
    )

    assert_equal "auth/app/omniauth/omniauth_callbacks", google_route[:controller]
    assert_equal "omniauth", google_route[:action]
    assert_equal "google", google_route[:provider]
    assert_equal "auth/app/omniauth/omniauth_callbacks", apple_get_route[:controller]
    assert_equal "omniauth", apple_get_route[:action]
    assert_equal "apple", apple_get_route[:provider]

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{host}/social/google/callback", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{host}/social/apple/callback", method: :post)
    end
  end

  test "failure logs the classification and never the raw parameters" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    injected_message = "attacker-supplied-marker-9f3c"
    injected_strategy = "attacker-supplied-strategy-7b1d"
    session_hash = {}

    controller.request = ActionDispatch::TestRequest.create("REQUEST_METHOD" => "GET")
    controller.response = ActionDispatch::TestResponse.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) {
      ActionController::Parameters.new(message: injected_message, strategy: injected_strategy)
    }
    controller.define_singleton_method(:redirect_to) { |*, **| nil }
    controller.define_singleton_method(:auth_app_sign_in_path) { |**| "/sign/in" }
    controller.define_singleton_method(:auth_app_sign_up_path) { |**| "/sign/up" }
    controller.define_singleton_method(:clear_social_auth_intent!) { nil }
    controller.define_singleton_method(:logged_in?) { false }

    buffer = StringIO.new
    previous_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(buffer)
    Rails.logger.level = Logger::DEBUG

    begin
      controller.failure
    ensure
      Rails.logger = previous_logger
    end

    logs = buffer.string

    assert_not_includes logs, injected_message
    assert_not_includes logs, injected_strategy
    assert_includes logs, "sign.social.omniauth_failure"
    assert_includes logs, %("message":"other")
    assert_includes logs, %("strategy":"other")
  end

  test "direct action early exits and csrf helpers" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    session_hash = {}
    redirects = []

    request = ActionDispatch::TestRequest.create("REQUEST_METHOD" => "GET")
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(provider: "apple", message: "cancelled", strategy: "apple") }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:auth_app_sign_in_path) { |ri: nil|
      "/sign/in#{"?ri=#{ri}" if ri}"
    }
    controller.define_singleton_method(:auth_app_sign_up_path) { |ri: nil|
      "/sign/up#{"?ri=#{ri}" if ri}"
    }
    controller.define_singleton_method(:clear_social_auth_intent!) { @cleared_for_test = true }
    controller.define_singleton_method(:test_mode_omniauth_auth_hash) { nil }

    controller.omniauth

    assert_match "/sign/in", redirects.last.first.first

    controller.failure

    assert controller.instance_variable_get(:@cleared_for_test)
    assert_match "/sign/in", redirects.last.first.first
  end
end
