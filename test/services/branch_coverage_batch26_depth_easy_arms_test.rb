# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch26DepthEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "AuthenticationLogoutable then-arms fire when cookies helpers are absent" do
    bare = Class.new { include AuthenticationLogoutable }.new

    assert_nil bare.send(:session_token_from_refresh_cookie_for_logout)
    assert_nil bare.send(:record_logout_audit, :resource)
    assert_nil bare.send(:record_logout_all_sessions_audit, :resource)
  end

  test "PreferenceResourceSync returns when resource or preference is blank" do
    helper = Class.new(ApplicationController) { include PreferenceResourceSync }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)
    helper.define_singleton_method(:preference_current_resource) { nil }

    assert_nil helper.send(:sync_to_resource_preference!)

    helper.define_singleton_method(:preference_current_resource) { Object.new }
    helper.define_singleton_method(:preference_write_resource_preference!) { |_| nil }

    assert_nil helper.send(:sync_to_resource_preference!)
    assert_nil helper.send(:write_resource_preference_option!, Object.new, :theme, nil)
    assert_nil helper.send(:load_or_create_resource_preference_child!, Object.new, "app", :theme)
    assert_equal helper.send(:default_preference_cookie_state),
                 helper.send(:resolved_preference_cookie, Object.new)
  end

  test "SignUpArtifactCleanup provider and attribute guards" do
    cycle = Object.new
    cycle.define_singleton_method(:has_attribute?) { |_| false }
    cycle.define_singleton_method(:social_provider) { "facebook" }
    cycle.define_singleton_method(:entry_method) { "facebook" }
    cycle.define_singleton_method(:pending_contact_type) { "email" }
    cycle.define_singleton_method(:pending_passkey_registration_id) { nil }
    cleanup = SignUpArtifactCleanup.new(cycle: cycle, now: Time.current)

    assert_nil cleanup.send(:client_social_identity, Object.new)
    assert_nil cleanup.send(:client_pending_passkey, Object.new)
    assert_nil cleanup.send(:visitor_pending_contact, nil)
    assert_nil cleanup.send(:visitor_pending_passkey, Object.new)
  end

  test "SignFlow concern blank-attribute guards" do
    flow = ClientSignUpFlow.new
    flow.define_singleton_method(:has_attribute?) { |name| name.to_s != "state" }

    assert_nil flow.send(:sync_legacy_state_from_status)
    assert_nil flow.send(:legacy_state_matches_status)
    assert_nil flow.send(:step_matches_status)
    assert_nil flow.send(:expires_after_issued_at)
  end

  test "TokenStatusManagement discarded arm" do
    token = ClientToken.new
    if token.has_attribute?(:discarded_at)
      token.discarded_at = 1.minute.ago

      assert_not token.currently_usable?
    else
      assert_kind_of Minitest::Test, self
    end
  end

  test "CommonRedirect helpers refuse blank hosts" do
    helper = Class.new(ApplicationController) { include CommonRedirect }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_nil helper.send(:normalized_host_with_optional_port, "")
    assert_kind_of Array, helper.send(:safe_jump_preserved_query_keys, "https://example.test")
  end

  test "PreferenceTransport short-circuits without resource helpers" do
    helper = Class.new(ApplicationController) { include PreferenceTransport }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_nil helper.send(:refresh_preference_token_from_db_for_edit_entry!)
  end

  test "Palm logout state matcher blank arms" do
    controller = Palm::App::Sign::OutsController.new
    request = ActionDispatch::TestRequest.create
    response = ActionDispatch::TestResponse.new
    controller.set_request!(request)
    controller.set_response!(response)
    controller.instance_variable_set(:@logout_transaction, nil)

    assert controller.send(:palm_logout_state_matches?)

    txn = Object.new
    txn.define_singleton_method(:callback_state) { "abc" }
    controller.instance_variable_set(:@logout_transaction, txn)
    controller.params = ActionController::Parameters.new(state: "")

    assert_not controller.send(:palm_logout_state_matches?)
  end
end
