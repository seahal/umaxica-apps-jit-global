# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::In::SessionsControllerBranchHarnessTest < ActiveSupport::TestCase
  test "update and destroy redirect to login when current client missing" do
    c = Auth::App::Sign::In::SessionsController.new
    request = ActionDispatch::TestRequest.create
    response = ActionDispatch::TestResponse.new
    c.set_request!(request)
    c.set_response!(response)
    redirects = []
    c.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    c.define_singleton_method(:session) { {} }
    c.define_singleton_method(:params) { ActionController::Parameters.new({}) }
    c.define_singleton_method(:resolve_current_client) { nil }
    c.define_singleton_method(:auth_app_sign_in_path) { |**| "/sign/in" }
    c.define_singleton_method(:current_region_identifier) { "jp" }
    c.send(:update)

    assert_predicate redirects, :present?
    redirects.clear
    c.define_singleton_method(:params) { ActionController::Parameters.new(ref: "x") }
    c.send(:destroy)

    assert_predicate redirects, :present?
  end
end
