# typed: false
# frozen_string_literal: true

require "test_helper"

class UmaxicaWithdrawalTimingPolicyValueTest < ActiveSupport::TestCase
  STANDARD = {
    recovery_delay: 1.hour,
    early_termination_delay: 7.days,
    retention_period: 31.days,
  }.freeze

  test "stores ordered durations immutably and exposes normalized seconds" do
    policy = Umaxica::Withdrawal::TimingPolicyValue.new(**STANDARD)

    assert_equal 1.hour.to_i, policy.recovery_delay_seconds
    assert_equal 7.days.to_i, policy.early_termination_delay_seconds
    assert_equal 31.days.to_i, policy.retention_period_seconds
    assert_predicate policy, :frozen?
    assert_predicate policy.recovery_delay, :frozen?
  end

  test "rejects non-positive or non-integer duration values" do
    invalid_values = [0, -1, 1.5, "3600"]

    invalid_values.each do |value|
      assert_raises(ArgumentError) do
        Umaxica::Withdrawal::TimingPolicyValue.new(
          recovery_delay: value,
          early_termination_delay: 2,
          retention_period: 3,
        )
      end
    end
  end

  test "rejects non-increasing timing windows" do
    [
      { recovery_delay: 2, early_termination_delay: 2, retention_period: 3 },
      { recovery_delay: 3, early_termination_delay: 2, retention_period: 4 },
      { recovery_delay: 1, early_termination_delay: 3, retention_period: 3 },
    ].each do |values|
      assert_raises(ArgumentError) { Umaxica::Withdrawal::TimingPolicyValue.new(**values) }
    end
  end

  test "uses the standard for an override omitted in development or test" do
    policy = Umaxica::Withdrawal::TimingPolicyValue.validate_environment!(
      environment: "test",
      environment_variables: {
        "UMAXICA_APP_COM_WITHDRAWAL_RECOVERY_DELAY_SECONDS" => "2",
      },
    )

    assert_equal 2, policy.recovery_delay_seconds
    assert_equal 7.days.to_i, policy.early_termination_delay_seconds
    assert_equal 31.days.to_i, policy.retention_period_seconds
  end

  test "rejects an override that becomes invalid after standard completion" do
    assert_raises(ArgumentError) do
      Umaxica::Withdrawal::TimingPolicyValue.validate_environment!(
        environment: "test",
        environment_variables: {
          "UMAXICA_APP_COM_WITHDRAWAL_EARLY_TERMINATION_DELAY_SECONDS" => "2678400",
        },
      )
    end
  end

  test "rejects every override in production, including blank and standard-valued entries" do
    ["", 1.hour.to_i.to_s].each do |value|
      assert_raises(ArgumentError) do
        Umaxica::Withdrawal::TimingPolicyValue.validate_environment!(
          environment: "production",
          environment_variables: {
            "UMAXICA_APP_COM_WITHDRAWAL_RECOVERY_DELAY_SECONDS" => value,
          },
        )
      end
    end
  end

  test "does not grant override permission to an unknown environment" do
    assert_raises(ArgumentError) do
      Umaxica::Withdrawal::TimingPolicyValue.validate_environment!(
        environment: "staging",
        environment_variables: {
          "UMAXICA_APP_COM_WITHDRAWAL_RECOVERY_DELAY_SECONDS" => "1",
        },
      )
    end
  end
end
