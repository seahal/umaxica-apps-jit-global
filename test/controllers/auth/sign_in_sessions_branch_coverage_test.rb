# typed: false
# frozen_string_literal: true

require "test_helper"

class SignInSessionsBranchCoverageTest < ActiveSupport::TestCase
  def build_com_controller
    Auth::Com::Sign::In::SessionsController.new
  end

  test "com sessions private helpers cover redirect login json cancel and promotion guards" do
    c = build_com_controller
    request = ActionDispatch::TestRequest.create
    response = ActionDispatch::TestResponse.new
    c.set_request!(request)
    c.set_response!(response)
    c.define_singleton_method(:session) { @session ||= {} }
    c.define_singleton_method(:current_region_identifier) { "jp" }
    redirects = []
    c.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    c.define_singleton_method(:head) { |status| @head = status }
    c.define_singleton_method(:auth_com_sign_in_path) { |**| "/sign/in" }

    c.send(:redirect_to_login)

    assert_predicate redirects, :present?

    c.define_singleton_method(:logged_in?) { false }
    c.define_singleton_method(:current_session_restricted?) { false }
    c.define_singleton_method(:pending_session_limit_cycle?) { false }
    c.define_singleton_method(:session_limit_gate_valid?) { false }
    c.send(:require_authentication_or_gate)

    assert_predicate redirects, :present?

    c.define_singleton_method(:logged_in?) { true }
    c.define_singleton_method(:current_session_restricted?) { false }
    c.define_singleton_method(:pending_session_limit_cycle?) { false }
    c.define_singleton_method(:session_limit_gate_valid?) { false }
    c.send(:require_authentication_or_gate)

    assert_equal :forbidden, c.instance_variable_get(:@head)

    request.format = :json
    c.define_singleton_method(:current_visitor) { nil }
    c.instance_variable_set(:@current_visitor, Object.new)
    c.define_singleton_method(:pending_session_limit_cycle?) { false }
    c.define_singleton_method(:consume_session_limit_gate!) { nil }
    c.define_singleton_method(:current_session) { nil }
    # destroy else branch with json
    c.define_singleton_method(:params) { ActionController::Parameters.new({}) }
    c.define_singleton_method(:resolve_current_visitor) { Object.new }
    flow = Object.new
    flow.define_singleton_method(:fail_sign_in!) { @failed = true }
    c.define_singleton_method(:current_db_sign_in_flow_for_sequence) { flow }
    c.define_singleton_method(:pending_session_limit_cycle?) { true }
    c.send(:destroy)

    assert_equal :no_content, c.instance_variable_get(:@head)

    # promote_current_session! no-op when not restricted
    c.define_singleton_method(:current_session) { nil }

    assert_nil c.send(:promote_current_session!)

    # session_item_props without last_used_at
    session = Struct.new(:public_id, :created_at, :last_used_at, :signed_ref).new("p1", Time.current, nil, "ref")
    c.instance_variable_set(:@current_session_public_id, "other")
    props = c.send(:session_item_props, session, label: "L", revocable: true)

    assert_nil props[:last_used_at]
    assert_nil props[:last_used_at_label]
    assert_equal "ref", props[:ref]

    # load_session_data without visitor
    c.define_singleton_method(:resolve_current_visitor) { nil }

    assert_nil c.send(:load_session_data)

    # revoke_sessions_by_refs skips current session
    visitor = Object.new
    token = Struct.new(:public_id).new("current")
    c.define_singleton_method(:current_session_public_id) { "current" }
    c.define_singleton_method(:current_session) { nil }
    c.define_singleton_method(:allowed_to?) { |*| true }
    VisitorToken.stub(:find_from_signed_refs, [token]) do
      ComTicketRecord.stub(:connected_to, ->(*, &block) { block.call }) do
        VisitorToken.stub(:transaction, ->(&b) { b.call }) do
          c.send(:revoke_sessions_by_refs, visitor, ["ref"])
        end
      end
    end
  end
end
