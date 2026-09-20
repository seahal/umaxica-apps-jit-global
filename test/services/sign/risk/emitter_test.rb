# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Sign
  module Risk
    class EmitterComprehensiveTest < ActiveSupport::TestCase
      fixtures :clients, :operators

      setup do
        ClientOccurrenceStatus.find_or_create_by!(id: ClientOccurrenceStatus::ACTIVE)
        VisitorOccurrenceStatus.ensure_defaults!
        @user = clients(:one)
      end

      test "emit returns nil when feature is disabled" do
        original = ENV["RISK_ENFORCEMENT_DISABLED"]
        ENV["RISK_ENFORCEMENT_DISABLED"] = "true"

        assert_nil SignRiskEmitter.emit("auth_failed", user_id: @user.id)
      ensure
        ENV["RISK_ENFORCEMENT_DISABLED"] = original
      end

      test "emit creates user occurrence when enabled" do
        original_disabled = ENV["RISK_ENFORCEMENT_DISABLED"]
        original_enabled = ENV["RISK_ENFORCEMENT_ENABLED"]
        ENV["RISK_ENFORCEMENT_DISABLED"] = nil
        ENV["RISK_ENFORCEMENT_ENABLED"] = "true"

        assert_difference "ClientOccurrence.count", 1 do
          SignRiskEmitter.emit("auth_failed", user_id: @user.id, ip: "1.2.3.4", reason: "bad_token")
        end

        occurrence = ClientOccurrence.order(:id).last

        assert_equal "risk.auth_failed", occurrence.event_type
        assert_includes occurrence.context, "user_id"
      ensure
        ENV["RISK_ENFORCEMENT_DISABLED"] = original_disabled
        ENV["RISK_ENFORCEMENT_ENABLED"] = original_enabled
      end

      test "emit creates staff occurrence when enabled" do
        original_disabled = ENV["RISK_ENFORCEMENT_DISABLED"]
        original_enabled = ENV["RISK_ENFORCEMENT_ENABLED"]
        ENV["RISK_ENFORCEMENT_DISABLED"] = nil
        ENV["RISK_ENFORCEMENT_ENABLED"] = "true"
        staff = operators(:one)
        OperatorOccurrenceStatus.find_or_create_by!(id: OperatorOccurrenceStatus::ACTIVE)

        assert_difference "OperatorOccurrence.count", 1 do
          SignRiskEmitter.emit("auth_failed", staff_id: staff.id, ip: "5.6.7.8", reason: "locked")
        end

        occurrence = OperatorOccurrence.order(:id).last

        assert_equal "risk.auth_failed", occurrence.event_type
        assert_includes occurrence.context, "staff_id"
      ensure
        ENV["RISK_ENFORCEMENT_DISABLED"] = original_disabled
        ENV["RISK_ENFORCEMENT_ENABLED"] = original_enabled
      end

      test "emit creates visitor occurrence with hmac context when enabled" do
        original_disabled = ENV["RISK_ENFORCEMENT_DISABLED"]
        original_enabled = ENV["RISK_ENFORCEMENT_ENABLED"]
        ENV["RISK_ENFORCEMENT_DISABLED"] = nil
        ENV["RISK_ENFORCEMENT_ENABLED"] = "true"

        option = ->(key, **) { (key == :OCCURRENCE_HMAC_SECRET) ? "secret_credential" : nil }

        Rails.app.creds.stub(:option, option) do
          assert_difference "VisitorOccurrence.count", 1 do
            SignRiskEmitter.emit(
              "auth_failed",
              visitor_id: 123,
              email: "Visitor@Example.com",
              ip: "203.0.113.10",
              reason: "bad_secret_credential",
            )
          end
        end

        occurrence = VisitorOccurrence.order(:id).last

        assert_equal "risk.auth_failed", occurrence.event_type
        assert_equal 123, occurrence.context.fetch("visitor_id")
        assert_match(/\A\h{64}\z/, occurrence.context.fetch("ip_hmac"))
        assert_match(/\A\h{64}\z/, occurrence.context.fetch("email_hmac"))
        assert_not_includes occurrence.context, "ip"
        assert_not_includes occurrence.context, "email"
      ensure
        ENV["RISK_ENFORCEMENT_DISABLED"] = original_disabled
        ENV["RISK_ENFORCEMENT_ENABLED"] = original_enabled
      end

      test "emit does nothing without actor id" do
        original_disabled = ENV["RISK_ENFORCEMENT_DISABLED"]
        original_enabled = ENV["RISK_ENFORCEMENT_ENABLED"]
        ENV["RISK_ENFORCEMENT_DISABLED"] = nil
        ENV["RISK_ENFORCEMENT_ENABLED"] = "true"

        assert_no_difference "ClientOccurrence.count" do
          SignRiskEmitter.emit("auth_failed", ip: "1.2.3.4")
        end
      ensure
        ENV["RISK_ENFORCEMENT_DISABLED"] = original_disabled
        ENV["RISK_ENFORCEMENT_ENABLED"] = original_enabled
      end

      test "emit handles exceptions gracefully" do
        original_disabled = ENV["RISK_ENFORCEMENT_DISABLED"]
        original_enabled = ENV["RISK_ENFORCEMENT_ENABLED"]
        ENV["RISK_ENFORCEMENT_DISABLED"] = nil
        ENV["RISK_ENFORCEMENT_ENABLED"] = "true"

        ClientOccurrence.stub(:create!, ->(**) { raise ActiveRecord::ActiveRecordError, "db error" }) do
          assert_nothing_raised do
            SignRiskEmitter.emit("auth_failed", user_id: @user.id)
          end
        end
      ensure
        ENV["RISK_ENFORCEMENT_DISABLED"] = original_disabled
        ENV["RISK_ENFORCEMENT_ENABLED"] = original_enabled
      end
    end
  end
end
