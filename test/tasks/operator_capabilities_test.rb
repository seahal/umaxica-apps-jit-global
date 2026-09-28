# typed: false
# frozen_string_literal: true

require "test_helper"
require "rake"
require "minitest/mock"

Rake::Task.define_task(:environment) unless Rake::Task.task_defined?("environment")
load Rails.root.join("lib/tasks/operator_capabilities.rake")

# The bootstrap task is the root of trust for the IAM capabilities. It runs here against the
# isolated test database only.
class OperatorCapabilitiesTaskTest < ActiveSupport::TestCase
  KEYS = %w(OPERATOR CAPABILITIES TICKET EXPIRES_AT DRY_RUN).freeze

  setup do
    @previous = KEYS.index_with { |key| ENV.fetch(key, nil) }
    @operator = operators(:one)
    # The compliance row normally comes from migration 20260926130000 (365 days, decided 2026-09-26);
    # a schema-only load skips that insert, so the test ensures it with the same value.
    ChronicleRetentionPolicy.find_or_create_by!(code: "compliance") do |policy|
      policy.name = "Compliance"
      policy.duration_days = 365
      policy.permanent = false
    end
  end

  teardown do
    @previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  test "grants every requested capability, records the audit, and prints no credential" do
    ENV["OPERATOR"] = @operator.public_id
    ENV["CAPABILITIES"] = "iam.capability.read, iam.capability.grant"
    ENV["TICKET"] = "OPS-100"
    ENV["EXPIRES_AT"] = 30.days.from_now.iso8601

    output, =
      capture_io do
      Rake::Task["operator_capabilities:bootstrap"].reenable
      Rake::Task["operator_capabilities:bootstrap"].invoke
    end

    grants = OperatorCapabilityGrant.where(operator: @operator, origin: "bootstrap")

    assert_equal %w(iam.capability.grant iam.capability.read), grants.pluck(:capability).sort
    event_uuid = output[/audit event_uuid=(\S+)/, 1]
    chronicle = Chronicle.find_by!(event_uuid: event_uuid)

    assert_equal ["iam.capability.bootstrapped", "succeeded"], [chronicle.action, chronicle.result]
    assert_no_match(/token|secret|password|Bearer/i, output)
  end

  test "dry run validates and writes neither grants nor audit" do
    ENV["OPERATOR"] = @operator.public_id
    ENV["CAPABILITIES"] = "iam.capability.read"
    ENV["TICKET"] = "OPS-101"
    ENV["EXPIRES_AT"] = 30.days.from_now.iso8601
    ENV["DRY_RUN"] = "true"

    assert_no_difference -> { OperatorCapabilityGrant.count } do
      assert_no_difference -> { Chronicle.count } do
        assert_output(/dry_run would grant/) do
          Rake::Task["operator_capabilities:bootstrap"].reenable
          Rake::Task["operator_capabilities:bootstrap"].invoke
        end
      end
    end
  end

  test "every required input is required" do
    base = { "OPERATOR" => @operator.public_id,
             "CAPABILITIES" => "iam.capability.read",
             "TICKET" => "OPS-102",
             "EXPIRES_AT" => 30.days.from_now.iso8601, }

    base.each_key do |missing|
      base.except(missing).each { |key, value| ENV[key] = value }
      ENV.delete(missing)

      Rake::Task["operator_capabilities:bootstrap"].reenable

      assert_raises(KeyError, "expected #{missing} to be required") do
        Rake::Task["operator_capabilities:bootstrap"].invoke
      end
    end
    assert_equal 0, OperatorCapabilityGrant.count
  end

  test "unknown, wildcard, empty, over-long, past, and malformed inputs grant nothing" do
    valid = { "OPERATOR" => @operator.public_id,
              "CAPABILITIES" => "iam.capability.read",
              "TICKET" => "OPS-103",
              "EXPIRES_AT" => 30.days.from_now.iso8601, }
    [
      valid.merge("CAPABILITIES" => "iam.*"), valid.merge("CAPABILITIES" => "*"),
      valid.merge("CAPABILITIES" => ""), valid.merge("CAPABILITIES" => " , "),
      valid.merge("CAPABILITIES" => "iam.capability.read,support.*"),
      valid.merge("EXPIRES_AT" => 367.days.from_now.iso8601), valid.merge("EXPIRES_AT" => 1.day.ago.iso8601),
      valid.merge("EXPIRES_AT" => "never"), valid.merge("TICKET" => ""), valid.merge("TICKET" => "has space"),
      valid.merge("OPERATOR" => "0000000000000000"),
    ].each do |inputs|
      inputs.each { |key, value| ENV[key] = value }

      Rake::Task["operator_capabilities:bootstrap"].reenable

      assert_raises(StandardError, "expected #{inputs.inspect} to be refused") do
        Rake::Task["operator_capabilities:bootstrap"].invoke
      end
    end
    assert_equal 0, OperatorCapabilityGrant.count
  end

  test "an admin-locked, withdrawing, or deactivated operator is refused" do
    ENV["CAPABILITIES"] = "iam.capability.read"
    ENV["TICKET"] = "OPS-104"
    ENV["EXPIRES_AT"] = 30.days.from_now.iso8601
    locked = operators(:two)
    locked.update_columns(
      access_state: "admin_locked", admin_locked_at: Time.current, # rubocop:disable Rails/SkipsModelValidations
      admin_locked_reason_code: "security_incident",
    )
    withdrawing = operators(:sample_staff)
    withdrawing.update_columns(withdrawal_started_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    deactivated = operators(:none_staff)
    deactivated.update_columns(deactivated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

    [locked, withdrawing, deactivated].each do |operator|
      ENV["OPERATOR"] = operator.public_id

      Rake::Task["operator_capabilities:bootstrap"].reenable

      assert_raises(ArgumentError) do
        Rake::Task["operator_capabilities:bootstrap"].invoke
      end
    end
    assert_equal 0, OperatorCapabilityGrant.count
  end

  test "a repeated run for a capability already in force is refused, and a partial list grants nothing" do
    ENV["OPERATOR"] = @operator.public_id
    ENV["TICKET"] = "OPS-105"
    ENV["EXPIRES_AT"] = 30.days.from_now.iso8601
    ENV["CAPABILITIES"] = "iam.capability.read"
    capture_io do
      Rake::Task["operator_capabilities:bootstrap"].reenable
      Rake::Task["operator_capabilities:bootstrap"].invoke
    end
    ENV["CAPABILITIES"] = "iam.capability.grant,iam.capability.read"

    Rake::Task["operator_capabilities:bootstrap"].reenable

    assert_raises(ArgumentError) do
      Rake::Task["operator_capabilities:bootstrap"].invoke
    end
    assert_equal ["iam.capability.read"], OperatorCapabilityGrant.pluck(:capability)
  end

  test "if the audit intent cannot be written, nothing is granted" do
    ENV["OPERATOR"] = @operator.public_id
    ENV["CAPABILITIES"] = "iam.capability.read"
    ENV["TICKET"] = "OPS-106"
    ENV["EXPIRES_AT"] = 30.days.from_now.iso8601

    ChronicleIntentWriter.stub(:call, ->(**) { raise ActiveRecord::ConnectionNotEstablished }) do
      Rake::Task["operator_capabilities:bootstrap"].reenable
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        Rake::Task["operator_capabilities:bootstrap"].invoke
      end
    end
    assert_equal 0, OperatorCapabilityGrant.count
  end
end
