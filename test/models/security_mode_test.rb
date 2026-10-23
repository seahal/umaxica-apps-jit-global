# frozen_string_literal: true

require "test_helper"

# adr/authentication-security-mode.md A2/A3/A5: NORMAL=3 and ADVANCED=7 are the only modes; every
# other value, including 0 and NULL, permits nothing.
class SecurityModeTest < ActiveSupport::TestCase
  [ClientSecurityMode, VisitorSecurityMode, OperatorSecurityMode].each do |model|
    test "#{model.name} defines exactly NORMAL and ADVANCED and its rows exist" do
      assert_equal [3, 7], model::DEFAULTS
      assert_equal [3, 7], model.order(:id).pluck(:id)
    end
  end

  { Client => :user_status, Visitor => :visitor_status, Operator => :staff_status }.each_key do |actor_class|
    [[nil, false, false, false], [0, false, false, false], [1, false, false, false], [3, true, true, false],
     [5, false, false, false], [7, true, false, true], [9, false, false, false],].each do |id, valid, normal, advanced|
      test "#{actor_class.name} security mode #{id.inspect} is valid=#{valid} normal=#{normal} advanced=#{advanced}" do
        actor = actor_class.new(security_mode_id: id)

        assert_equal [valid, normal, advanced],
                     [actor.security_mode_valid?, actor.security_mode_normal?, actor.security_mode_advanced?]
      end
    end
  end

  test "the database refuses a mode outside NORMAL and ADVANCED" do
    assert_raises(ActiveRecord::StatementInvalid) do
      ClientSecurityMode.transaction(requires_new: true) { ClientSecurityMode.insert!({ id: 5 }) }
    end
  end
end
