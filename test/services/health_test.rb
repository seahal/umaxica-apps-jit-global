# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class HealthTest < ActiveSupport::TestCase
  FakeCheck =
    Struct.new(:result) do
      def call = result
    end

  test "dependency result exposes only non-sensitive public status" do
    result = Health::DependencyResult.new(kind: :database, status: :unready, message: "Dependency unavailable")

    assert_not result.ok?
    assert_equal "failed", result.public_status
  end

  test "dependency result rejects unknown statuses" do
    assert_raises(ArgumentError) do
      Health::DependencyResult.new(kind: :database, status: :broken)
    end
  end

  test "check result serializes the public contract" do
    result = Health::CheckResult.new(
      check: :readiness,
      status: :ok,
      surface: "fake",
      dependencies: { "database" => "ok" },
    )

    json = result.as_public_json

    assert_equal "ok", json[:status]
    assert_equal "readiness", json[:check]
    assert_equal({ "database" => "ok" }, json[:dependencies])
    assert_not_includes json[:details].keys, :surface
  end

  test "check result collapses non-ok status to unavailable and keeps internal status in details" do
    result = Health::CheckResult.new(check: :readiness, status: :unready, surface: "fake")

    assert_not result.ok?
    assert_equal 503, result.http_status
    assert_equal "unavailable", result.as_public_json[:status]
    assert_equal "unready", result.as_public_json.dig(:details, :status)
    assert_not_includes result.as_public_json[:details].keys, :surface
  end

  test "check result rejects unknown statuses" do
    assert_raises(ArgumentError) do
      Health::CheckResult.new(check: :readiness, status: :broken, surface: "fake")
    end
  end

  test "status policy maps acceptable degraded by profile" do
    degraded = Health::DependencyResult.new(kind: :database, status: :degraded_acceptable)
    strict_policy = Health::StatusPolicy.new
    accepting_policy = Health::StatusPolicy.new(acceptable_degraded_kinds: [:database])

    assert_equal :unready, strict_policy.status_for([degraded])
    assert_equal :degraded_acceptable, accepting_policy.status_for([degraded])
  end

  test "http status mapping is centralized" do
    assert_equal 200, Health::StatusPolicy.http_status(:ok, probe: :readiness)
    assert_equal 200, Health::StatusPolicy.http_status(:degraded_acceptable, probe: :readiness)
    assert_equal 503, Health::StatusPolicy.http_status(:unready, probe: :readiness)
    assert_equal 503, Health::StatusPolicy.http_status(:starting, probe: :readiness)
    assert_equal 200, Health::StatusPolicy.http_status(:starting, probe: :liveness)
  end

  test "status policy rejects unknown status" do
    assert_raises(ArgumentError) { Health::StatusPolicy.http_status(:broken, probe: :readiness) }
  end

  test "profile dependency allowlists are explicit" do
    assert_equal [AppRpRecord, AppSettingRecord, AppSignalRecord, AvatarRecord, OccurrenceRecord],
                 Health::Profiles::App.record_classes
    assert_equal [OrgRpRecord, OrgSettingRecord, OrgSignalRecord], Health::Profiles::Org.record_classes
    assert_equal [AppPrincipalRecord, AppTicketRecord, AppSettingRecord], Health::Profiles::SignApp.record_classes
  end

  test "liveness check never touches dependencies" do
    result = Health::LivenessCheck.call(profile: Health::Profiles::SignApp)

    assert_predicate result, :ok?
    assert_equal :liveness, result.check
    assert_empty result.dependencies
  end

  test "readiness checks only the current profile dependencies" do
    called = []
    profile = fake_profile(
      checks: [
        FakeCheck.new(Health::DependencyResult.new(kind: :database, status: :ok)),
        FakeCheck.new(Health::DependencyResult.new(kind: :database, status: :ok)),
      ],
    )
    profile.readiness_checks.each_with_index do |check, index|
      check.define_singleton_method(:call) do
        called << index
        result
      end
    end

    result = Health::ReadinessCheck.new(profile: profile).call

    assert_predicate result, :ok?
    assert_equal({ "database" => "ok" }, result.dependencies)
    assert_equal [0, 1], called
  end

  test "readiness reports failed dependency without leaking internals" do
    profile = fake_profile(
      checks: [FakeCheck.new(
        Health::DependencyResult.new(
          kind: :database, status: :unready,
          message: "Dependency unavailable",
        ),
      )],
    )

    result = Health::ReadinessCheck.new(profile: profile).call

    assert_not result.ok?
    assert_equal({ "database" => "failed" }, result.dependencies)
  end

  test "readiness evaluates profile probe independently" do
    first_profile = fake_profile(
      cache_key: "first",
      checks: [FakeCheck.new(Health::DependencyResult.new(kind: :database, status: :ok))],
    )
    second_profile = fake_profile(
      cache_key: "second",
      checks: [FakeCheck.new(Health::DependencyResult.new(kind: :database, status: :unready))],
    )

    assert_predicate Health::ReadinessCheck.new(profile: first_profile).call, :ok?
    assert_not Health::ReadinessCheck.new(profile: second_profile).call.ok?
  end

  test "readiness reevaluates dependencies without cache reuse" do
    result = Health::DependencyResult.new(kind: :database, status: :ok)
    calls = 0
    check = Object.new
    check.define_singleton_method(:call) do
      calls += 1
      result
    end
    profile = fake_profile(checks: [check])

    assert_predicate Health::ReadinessCheck.new(profile: profile).call, :ok?
    result = Health::DependencyResult.new(kind: :database, status: :unready)

    assert_not Health::ReadinessCheck.new(profile: profile).call.ok?
    assert_equal 2, calls
  end

  test "readiness timeout returns unavailable result" do
    check = Object.new
    check.define_singleton_method(:call) { raise Health::DeadlineExceeded }
    profile = fake_profile(checks: [check])

    result = Health::ReadinessCheck.new(profile: profile).call

    assert_not result.ok?
  end

  test "database check reports unready when connection fails" do
    failing_record_class =
      Class.new do
        def self.connected_to(_role:, &)
          raise StandardError, "connection refused"
        end
      end

    result = Health::Checks::Database.new(record_class: failing_record_class, deadline: 1.0).call

    assert_not result.ok?
    assert_equal :database, result.kind
    assert_equal :unready, result.status
    assert_equal "Dependency unavailable", result.message
  end

  test "database check runs the probe directly when Prosopite is unavailable" do
    prosopite = defined?(Prosopite) ? Prosopite : nil
    Object.send(:remove_const, :Prosopite) if prosopite

    fake_connection = Object.new
    fake_connection.define_singleton_method(:execute) { |_| 1 }
    record_class = Class.new
    record_class.define_singleton_method(:connection_class_for_self) { record_class }
    record_class.define_singleton_method(:connected_to) do |**, &block|
      block.call
    end
    record_class.define_singleton_method(:with_connection) do |&block|
      block.call(fake_connection)
    end

    result = Health::Checks::Database.new(record_class: record_class, deadline: 1.0).call

    assert_predicate result, :ok?
    assert_equal :database, result.kind
    assert_equal :ok, result.status
  ensure
    Object.const_set(:Prosopite, prosopite) if prosopite && !defined?(Prosopite)
  end

  test "startup uses only the boot check" do
    result = Health::StartupCheck.call(profile: Health::Profiles::SignApp)

    assert_predicate result, :ok?
    assert_equal :startup, result.check
    assert_empty result.dependencies
  end

  test "startup reports unavailable while booting" do
    Rails.application.stub(:initialized?, false) do
      result = Health::StartupCheck.call(profile: Health::Profiles::SignApp)

      assert_not result.ok?
      assert_equal "starting", result.as_public_json.dig(:details, :status)
    end
  end

  test "snapshot aggregates the three probes as nested dependencies" do
    result = Health::SnapshotCheck.call(profile: Health::Profiles::SignApp)
    json = result.as_public_json

    assert_equal "health", json[:check]
    assert_equal %w(liveness readiness startup), json[:dependencies].keys
  end

  private

  def fake_profile(cache_key: "fake", checks:)
    Struct.new(:cache_key, :surface_label, :status_policy, :readiness_checks).new(
      cache_key,
      "fake",
      Health::StatusPolicy.new,
      checks,
    )
  end
end
