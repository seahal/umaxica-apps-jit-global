# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Sign
  module Risk
    class EngineComprehensiveTest < ActiveSupport::TestCase
      fixtures :clients

      setup do
        ClientOccurrenceStatus.find_or_create_by!(id: ClientOccurrenceStatus::ACTIVE)
        VisitorOccurrenceStatus.ensure_defaults!
        @user = clients(:one)

        original_disabled = ENV["RISK_ENFORCEMENT_DISABLED"]
        original_enabled = ENV["RISK_ENFORCEMENT_ENABLED"]
        ENV["RISK_ENFORCEMENT_DISABLED"] = nil
        ENV["RISK_ENFORCEMENT_ENABLED"] = "true"
        @original_disabled = original_disabled
        @original_enabled = original_enabled
      end

      teardown do
        ENV["RISK_ENFORCEMENT_DISABLED"] = @original_disabled
        ENV["RISK_ENFORCEMENT_ENABLED"] = @original_enabled
      end

      test "score returns 0 when no user_id or staff_id provided" do
        assert_equal 0, SignRiskEngine.score
      end

      test "score returns 0 for user with no events" do
        assert_equal 0, SignRiskEngine.score(user_id: @user.id)
      end
    end
  end
end
