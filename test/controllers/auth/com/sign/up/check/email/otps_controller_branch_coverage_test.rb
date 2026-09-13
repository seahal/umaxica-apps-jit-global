# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::Sign::Up::Check::Email::OtpsControllerBranchCoverageTest < ActiveSupport::TestCase
  test "create redirects invalid session when email missing after gate" do
    c = Auth::Com::Sign::Up::Check::Email::OtpsController.new
    request = ActionDispatch::TestRequest.create
    response = ActionDispatch::TestResponse.new
    c.set_request!(request)
    c.set_response!(response)
    redirects = []
    c.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    c.define_singleton_method(:redirect_invalid_session) { redirects << :invalid; nil }
    c.define_singleton_method(:load_gate_context!) { |_| true }
    c.define_singleton_method(:params) { ActionController::Parameters.new({}) }
    c.instance_variable_set(:@user_email, nil)
    c.send(:create)

    assert_includes redirects, :invalid
  end

  test "update redirects invalid session when email session invalid" do
    c = Auth::Com::Sign::Up::Check::Email::OtpsController.new
    request = ActionDispatch::TestRequest.create
    response = ActionDispatch::TestResponse.new
    c.set_request!(request)
    c.set_response!(response)
    redirects = []
    c.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    c.define_singleton_method(:redirect_invalid_session) { redirects << :invalid; nil }
    c.define_singleton_method(:render_code_required) { redirects << :code; nil }
    c.define_singleton_method(:load_gate_context!) { |_| true }
    c.define_singleton_method(:valid_email_session?) { false }
    c.define_singleton_method(:params) { ActionController::Parameters.new(code: "123456") }
    c.send(:update)

    assert_includes redirects, :invalid
  end
end
