# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::Sign::In::SessionsControllerBranchHarnessTest < ActiveSupport::TestCase
  test "update redirects when operator missing and promote no-ops" do
    c = Auth::Org::Sign::In::SessionsController.new
    request = ActionDispatch::TestRequest.create
    response = ActionDispatch::TestResponse.new
    c.set_request!(request)
    c.set_response!(response)
    redirects = []
    c.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    c.define_singleton_method(:session) { {} }
    c.define_singleton_method(:params) { ActionController::Parameters.new({}) }
    c.define_singleton_method(:resolve_current_operator) { nil }
    c.define_singleton_method(:auth_org_sign_in_path) { |**| "/sign/in" }
    c.define_singleton_method(:current_region_identifier) { "jp" }
    c.send(:update)

    assert_predicate redirects, :present?
    c.define_singleton_method(:current_session) { nil }

    assert_nil c.send(:promote_current_session!)
  end
end
