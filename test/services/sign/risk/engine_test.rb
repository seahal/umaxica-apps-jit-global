# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Sign
  module Risk
    class EngineTest < ActiveSupport::TestCase
      setup do
        ClientOccurrenceStatus.find_or_create_by!(id: ClientOccurrenceStatus::ACTIVE)
        VisitorOccurrenceStatus.ensure_defaults!
        @user = Client.create!(status_id: ClientStatus::NOTHING, public_id: "risk_#{SecureRandom.hex(6)}")
      end

      test "refresh_reuse_detected returns 100" do
        # SignRiskEngine scores from the occurrence tables in PostgreSQL, so the
        # events are seeded through the emitter rather than through a store double.
        SignRiskEmitter.send(:persist, SignRiskEvent.new("refresh_reuse_detected", payload: { user_id: @user.id }))

        assert_equal 100, SignRiskEngine.score(user_id: @user.id)
      end

      test "auth_failed 5 times returns 60" do
        5.times do
          SignRiskEmitter.send(:persist, SignRiskEvent.new("auth_failed", payload: { user_id: @user.id }))
        end

        assert_equal 60, SignRiskEngine.score(user_id: @user.id)
      end

      test "refresh_failed 5 times returns 40" do
        5.times do
          SignRiskEmitter.send(:persist, SignRiskEvent.new("refresh_failed", payload: { user_id: @user.id }))
        end

        assert_equal 40, SignRiskEngine.score(user_id: @user.id)
      end

      test "mixed events return max score" do
        SignRiskEmitter.send(:persist, SignRiskEvent.new("refresh_reuse_detected", payload: { user_id: @user.id }))
        5.times { SignRiskEmitter.send(:persist, SignRiskEvent.new("auth_failed", payload: { user_id: @user.id })) }

        assert_equal 100, SignRiskEngine.score(user_id: @user.id)
      end

      test "ip_change_detected returns 100 when the anomaly-revoke flag is enabled" do
        SignRiskEmitter.send(:persist, SignRiskEvent.new("ip_change_detected", payload: { user_id: @user.id }))

        SignRiskEngine.stub(:ip_anomaly_revoke_enabled?, true) do
          assert_equal 100, SignRiskEngine.score(user_id: @user.id)
        end
      end

      test "ip_change_detected is signal-only when the anomaly-revoke flag is disabled" do
        SignRiskEmitter.send(:persist, SignRiskEvent.new("ip_change_detected", payload: { user_id: @user.id }))

        SignRiskEngine.stub(:ip_anomaly_revoke_enabled?, false) do
          assert_equal 0, SignRiskEngine.score(user_id: @user.id)
        end
      end

      test "returns 0 for safe events" do
        SignRiskEmitter.send(:persist, SignRiskEvent.new("session_issued", payload: { user_id: @user.id }))

        assert_equal 0, SignRiskEngine.score(user_id: @user.id)
      end

      test "visitor auth_failed 5 times returns 60" do
        5.times do
          SignRiskEmitter.send(:persist, SignRiskEvent.new("auth_failed", payload: { visitor_id: 123 }))
        end

        assert_equal 60, SignRiskEngine.score(visitor_id: 123)
      end
    end
  end
end
