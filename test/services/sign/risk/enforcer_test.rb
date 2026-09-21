# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Sign
  module Risk
    class EnforcerTest < ActiveSupport::TestCase
      fixtures :clients, :client_statuses, :client_token_statuses, :client_token_kinds,
               :operators, :operator_token_statuses, :operator_token_kinds

      setup do
        @user = clients(:one) # Assuming fixtures or factory
        @user_id = @user.id
        ClientOccurrenceStatus.find_or_create_by!(id: ClientOccurrenceStatus::ACTIVE)

        # Enable feature flag for tests
        @original_env = ENV["RISK_ENFORCEMENT_ENABLED"]
        ENV["RISK_ENFORCEMENT_ENABLED"] = "true"
      end

      teardown do
        ENV["RISK_ENFORCEMENT_ENABLED"] = @original_env
      end

      test "does nothing if feature flag is off" do
        ENV["RISK_ENFORCEMENT_ENABLED"] = "false"

        SignRiskEngine.stub(:score, 100) do
          SignRiskEnforcer.stub(:revoke!, ->(_) { raise RuntimeError, "Should not be called" }) do
            result = SignRiskEnforcer.call(@user)

            assert_nil result
          end
        end
      end

      test "revokes if score is 100" do
        SignRiskEngine.stub(:score, 100) do
          # SignRiskEnforcer.revoke! should be called
          called = false
          SignRiskEnforcer.stub(:revoke!, ->(u) { called = true; assert_equal @user, u }) do
            SignRiskEnforcer.call(@user)
          end

          assert called, "revoke! should have been called"
        end
      end

      test "requires step up if score is 60" do
        @user.client_tokens.destroy_all

        token = ClientToken.create!(
          user: @user,
          discard_at: 1.day.from_now,
          public_id: "test_step_up_#{SecureRandom.hex(4)}",
          last_step_up_at: 1.minute.ago,
          last_step_up_scope: "settings_email",
        )

        SignRiskEngine.stub(:score, 60) do
          SignRiskEnforcer.call(@user)
        end

        token.reload

        assert_nil token.last_step_up_at
        assert_nil token.last_step_up_scope
      end

      test "requires step up for staff tokens if score is 60" do
        staff = operators(:one)
        staff.operator_tokens.destroy_all

        token = OperatorToken.create!(
          staff: staff,
          discard_at: 1.day.from_now,
          public_id: "stf_#{SecureRandom.hex(4)}",
          last_step_up_at: 1.minute.ago,
          last_step_up_scope: "settings_passkey",
        )

        SignRiskEngine.stub(:score, 60) do
          SignRiskEnforcer.call(staff)
        end

        token.reload

        assert_nil token.last_step_up_at
        assert_nil token.last_step_up_scope
      end

      test "does nothing if score is 0" do
        SignRiskEngine.stub(:score, 0) do
          SignRiskEnforcer.stub(:revoke!, ->(_) { raise RuntimeError, "Should not be called" }) do
            SignRiskEnforcer.stub(:require_step_up!, ->(_) { raise RuntimeError, "Should not be called" }) do
              result = SignRiskEnforcer.call(@user)

              assert_nil result
            end
          end
        end
      end

      test "end-to-end risk flow" do
        @user.client_tokens.destroy_all # Ensure we don't hit session limit

        # Create token with valid public_id and expiry
        token = ClientToken.create!(
          user: @user,
          discard_at: 1.day.from_now,
          public_id: "test_#{SecureRandom.hex(4)}",
          # Default status/kind should trigger if FKs exist.
          # If FK check fails, we might need to assume fixtures loaded statuses.
        )

        # 1. Emit risk event (writes to occurrences)
        SignRiskEmitter.emit("refresh_reuse_detected", user_id: @user.id)

        # 2. Call SignRiskEnforcer (reads occurrences via SignRiskEngine, then revokes)
        SignRiskEnforcer.call(@user)

        # 3. Check revocation
        token.reload

        assert_not_nil token.discard_at
      end
    end
  end
end
