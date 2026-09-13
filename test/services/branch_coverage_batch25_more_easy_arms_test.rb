# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch25MoreEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "OrgOperatorLifecycleExecute blank-target short circuits" do
    request = Object.new
    request.define_singleton_method(:target_operator) { nil }
    service = OrgOperatorLifecycleExecute.new(request: request, actor: Operator.new)

    assert_nil service.send(:withdraw_operator!)
    assert_nil service.send(:suspend_operator!)
    assert_nil service.send(:terminate_operator!)
    assert_nil service.send(:restore_operator!)
  end

  test "OidcEndSessionRequest blank actor helpers" do
    request = OidcEndSessionRequest.new(params: {}, request: ActionDispatch::TestRequest.create)
    request.define_singleton_method(:actor) { nil }

    assert_nil request.send(:current_subject)

    unauth = Object.new
    unauth.define_singleton_method(:unauthenticated?) { true }
    request.define_singleton_method(:actor) { unauth }

    assert_nil request.send(:current_actor)
  end

  test "AuthenticationDeviceBinding short-circuits without columns and blank sessions" do
    helper = Class.new(ApplicationController) { include AuthenticationDeviceBinding }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)
    helper.define_singleton_method(:token_record_column?) { |_| false }
    helper.define_singleton_method(:device_session_class) { nil }

    assert_nil helper.send(:find_token_record_by_device_session_identifier, "sid")
    assert_nil helper.send(:find_device_session_by_public_id, "pid")
    assert_nil helper.send(:update_device_session_refresh_state!, nil, Object.new)
    assert_nil helper.send(:ensure_device_session_for!, Object.new, Object.new)
  end

  test "WithdrawalCeremonyReentry state and eligibility guards" do
    helper = Class.new(ApplicationController) { include WithdrawalCeremonyReentry }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)
    helper.define_singleton_method(:session) { @__session ||= {} }

    assert_nil helper.send(:withdrawal_reentry_state)
    helper.session[WithdrawalCeremonyReentry::REENTRY_SESSION_KEY] = { "expires_at" => 1 }
    helper.send(:withdrawal_reentry_state)

    assert_nil helper.session[WithdrawalCeremonyReentry::REENTRY_SESSION_KEY]
    assert_not helper.send(:withdrawal_reentry_subject_eligible?, Object.new)
  end
end
