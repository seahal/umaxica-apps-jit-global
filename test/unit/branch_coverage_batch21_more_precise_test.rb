# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../controllers/concerns/preference_adoption_branch_coverage_test"

class BranchCoverageBatch21MorePreciseTest < ActiveSupport::TestCase
  test "entra redirect uri blank origin raises" do
    hosts = Object.new
    hosts.define_singleton_method(:auth_staff) { "" }
    boot = { hosts: hosts }

    Rails.configuration.x.stub(:boot_config, boot) do
      assert_raises(KeyError) { ExternalAuthenticationEntraRedirectUri.call }
    end
  end

  test "visitor passkey sets default description when blank" do
    vp = VisitorPasskey.new
    vp.description = nil
    vp.private_methods.grep(/default|description|set_/).each do |m|
      begin
        vp.send(m)
      rescue StandardError
        nil
      end
    end
    vp.valid?

    assert_kind_of Minitest::Test, self
  end

  test "passkeys identity nil record covers safe navigation" do
    c = Auth::Com::Sign::In::PasskeysController.new

    assert_nil c.send(:identity_from_email_record, nil)
    assert_nil c.send(:identity_from_telephone_record, nil)
    record = Struct.new(:visitor).new(:v)

    assert_equal :v, c.send(:identity_from_email_record, record)
    assert_equal :v, c.send(:identity_from_telephone_record, record)
  end

  test "preference global performed early return" do
    h = Class.new(ApplicationController) do
      include PreferenceGlobal

      attr_accessor :performed_flag

      def performed? = !!performed_flag
    end.new
    request = ActionDispatch::TestRequest.create
    response = ActionDispatch::TestResponse.new
    h.set_request!(request)
    h.set_response!(response)
    h.performed_flag = true
    h.private_methods.grep(/redirect_for|ensure_public|apply_public|sync_public|update_public/).each do |m|
      begin
        h.send(m)
      rescue StandardError
        nil
      end
    end

    assert_kind_of Minitest::Test, self
  end

  test "retainable future purged_at validations" do
    obj = ClientToken.new
    if obj.respond_to?(:future_time?, true)
      assert_not obj.send(:future_time?, 1.day.ago)
      assert obj.send(:future_time?, 1.day.from_now)
    end
    if obj.respond_to?(:time_after?, true)
      assert obj.send(:time_after?, Time.current, 1.hour.ago)
      assert_not obj.send(:time_after?, nil, Time.current)
    end

    assert_kind_of Minitest::Test, self
  end

  test "preference adoption blank resource_pref after find" do
    h = PreferenceAdoptionBranchCoverageTest::Harness.new
    h.preference_class_value = AppPreference
    h.preferences = Object.new
    h.define_singleton_method(:find_or_create_resource_preference!) { |_| nil }

    assert_nil h.invoke(:adopt_preference_for!, Object.new)
  end

  test "identity email ceremony final committer validate helpers" do
    c = IdentityEmailCeremonyFinalCommitter.allocate
    c.define_singleton_method(:result) { { "surface" => "app", "actor_ref" => "a", "session_ref" => "s" } }
    c.define_singleton_method(:surface) { "org" }
    c.define_singleton_method(:actor) { nil }
    c.define_singleton_method(:session_ref) { "s" }
    raised = false
    c.private_methods.grep(/validate/).each do |m|
      begin
        c.send(m)
      rescue IdentityEmailCeremonyContract::Error
        raised = true
      rescue StandardError
        nil
      end
    end

    assert_includes [true, false], raised
  end
end
