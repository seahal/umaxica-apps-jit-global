# typed: false
# frozen_string_literal: true

require "timeout"

module Health
  MissingProfileError = Class.new(StandardError)
  MissingNamespaceError = Class.new(StandardError)
  MalformedSnapshotError = Class.new(StandardError)
  DeadlineExceeded = Class.new(StandardError)

  STATUSES = %i(ok degraded_acceptable unready starting).freeze

  # Common result object returned by every Health::*Check.call.
  #
  # It is the single source of the public health contract: it owns JSON
  # serialization (`as_public_json`) and the HTTP status decision
  # (`http_status` / `ok?`). Controllers and the snapshot view never hand-roll
  # health JSON; they derive everything from this object.
  class CheckResult
    attr_reader :check, :status, :dependencies, :surface, :generated_at, :revision

    def initialize(check:, status:, surface:, dependencies: {}, generated_at: Time.current,
                   revision: Rails.app.revision.to_s)
      @check = check.to_sym
      @status = status.to_sym
      raise ArgumentError, "unknown health status: #{@status}" unless STATUSES.include?(@status)

      @dependencies = dependencies.freeze
      @surface = surface
      @generated_at = generated_at.utc
      @revision = revision.presence
    end

    def ok?
      http_status == 200
    end

    def http_status
      StatusPolicy.http_status(status, probe: check)
    end

    # `namespace` names the routed surface that answered, as "<realm>/<surface>"
    # (for example "core/app"). One Rails process answers on fifteen hostnames and the
    # probe bodies were otherwise identical, so a caller that sent the wrong `Host` still
    # saw a 200 and could not tell which surface produced it. The value is derived from the
    # controller that ran, not from a constant listed beside the route, so it cannot drift
    # away from the constraint that selected it.
    #
    # It is emitted in every environment. It is a function of the `Host` the caller already
    # chose, so it tells a reader nothing they did not supply, and the acceptance check that
    # needs it runs against the production path. Nested dependency results omit it; the
    # surface is a property of the response, not of each dependency.
    def as_public_json(namespace: nil)
      {
        status: ok? ? "ok" : "unavailable",
        check: check.to_s,
        namespace: namespace,
        dependencies: dependencies,
        details: details,
      }.compact
    end

    # Non-sensitive diagnostic metadata only. Never exception classes,
    # messages, connection topology, or credentials. The answering surface is named at the
    # top level by `namespace`, deliberately; it is not repeated here.
    def details
      details = { generated_at: generated_at.iso8601(3) }
      details[:revision] = revision if revision
      details[:status] = status.to_s unless status == :ok
      details
    end
  end

  # Result of a single dependency probe, aggregated into a CheckResult.
  class DependencyResult
    attr_reader :kind, :status, :message

    def initialize(kind:, status:, message: nil)
      status = status.to_sym
      raise ArgumentError, "unknown health status: #{status}" unless STATUSES.include?(status)

      @kind = kind.to_sym
      @status = status
      @message = message
    end

    def ok?
      status == :ok
    end

    def public_status
      ok? ? "ok" : "failed"
    end
  end

  # Centralizes dependency status aggregation and HTTP status mapping.
  class StatusPolicy
    def self.http_status(status, probe:)
      return 200 if status.to_sym == :starting && probe.to_sym == :liveness

      case status.to_sym
      when :ok, :degraded_acceptable
        200
      when :unready, :starting
        503
      else
        raise ArgumentError, "unknown health status: #{status}"
      end
    end

    def initialize(acceptable_degraded_kinds: [])
      @acceptable_degraded_kinds = acceptable_degraded_kinds.map(&:to_sym).freeze
    end

    def status_for(results)
      return :ok if results.all?(&:ok?)
      return :starting if results.any? { |result| result.status == :starting }
      return :degraded_acceptable if degraded_acceptable?(results)

      :unready
    end

    private

    attr_reader :acceptable_degraded_kinds

    def degraded_acceptable?(results)
      failing = results.reject(&:ok?)

      failing.present? && failing.all? do |result|
        result.status == :degraded_acceptable && acceptable_degraded_kinds.include?(result.kind)
      end
    end
  end

  module Checks
    # Startup check: confirms Rails finished initialization. Intentionally
    # lightweight; it must not touch external dependencies.
    class Boot
      def call
        return DependencyResult.new(kind: :boot, status: :ok) if Rails.application.initialized?

        DependencyResult.new(kind: :boot, status: :starting, message: "Application is starting")
      end
    end

    # Readiness dependency check for writing and reading database roles. The
    # exception class is logged internally but never serialized publicly.
    class Database
      SQL = "SELECT 1"
      ROLES = %i(writing reading).freeze

      def initialize(record_class:, deadline: 0.2)
        @record_class = record_class
        @deadline = deadline
      end

      def call
        with_deadline { check_roles }

        DependencyResult.new(kind: :database, status: :ok)
      rescue StandardError => e
        Rails.logger.info(
          JitLogEvent.format("health_check.database_failed", error_class: e.class.name),
        )
        DependencyResult.new(kind: :database, status: :unready, message: "Dependency unavailable")
      end

      private

      attr_reader :record_class, :deadline

      def check_roles
        operation =
          lambda do
            ROLES.each do |role|
              record_class.connected_to(role: role) do
                record_class.with_connection { |connection| connection.execute(SQL) }
              end
            end
          end

        if defined?(Prosopite)
          Prosopite.pause(&operation)
        else
          operation.call
        end
      end

      def with_deadline(&)
        Timeout.timeout(deadline, DeadlineExceeded, &)
      end
    end
  end

  module Profiles
    # Declares the dependency allowlist and status policy for one surface.
    class Base
      attr_reader :cache_key, :surface_label, :record_classes, :status_policy

      def initialize(cache_key:, surface_label:, record_classes:, status_policy: StatusPolicy.new)
        @cache_key = cache_key
        @surface_label = surface_label
        @record_classes = record_classes.freeze
        @status_policy = status_policy
      end

      def readiness_checks
        record_classes.map { |record_class| Checks::Database.new(record_class: record_class) }
      end
    end

    App = Base.new(
      cache_key: "acme-app",
      surface_label: "app",
      record_classes: [
        AppRpRecord,
        AppSettingRecord,
        AppSignalRecord,
        AvatarRecord,
        OccurrenceRecord,
      ],
    )

    Com = Base.new(
      cache_key: "acme-com",
      surface_label: "com",
      record_classes: [
        ComRpRecord,
        ComSettingRecord,
        ComSignalRecord,
      ],
    )

    Org = Base.new(
      cache_key: "acme-org",
      surface_label: "org",
      record_classes: [
        OrgRpRecord,
        OrgSettingRecord,
        OrgSignalRecord,
      ],
    )

    SignApp = Base.new(
      cache_key: "sign-app",
      surface_label: "sign app",
      record_classes: [
        AppPrincipalRecord,
        AppTicketRecord,
        AppSettingRecord,
      ],
    )

    SignCom = Base.new(
      cache_key: "sign-com",
      surface_label: "sign com",
      record_classes: [
        ComPrincipalRecord,
        ComTicketRecord,
        ComSettingRecord,
      ],
    )

    SignOrg = Base.new(
      cache_key: "sign-org",
      surface_label: "sign org",
      record_classes: [
        OrgPrincipalRecord,
        OrgTicketRecord,
        OrgSettingRecord,
      ],
    )
  end

  # Liveness probe: only confirms the Rails process can respond.
  class LivenessCheck
    def self.call(profile:)
      new(profile: profile).call
    end

    def initialize(profile:)
      @profile = profile
    end

    def call
      status = Rails.application.initialized? ? :ok : :starting

      CheckResult.new(check: :liveness, status: status, surface: profile.surface_label)
    end

    private

    attr_reader :profile
  end

  # Readiness probe: decides whether traffic may be routed to this instance.
  class ReadinessCheck
    TOTAL_DEADLINE = 1.0

    def self.call(profile:)
      new(profile: profile).call
    end

    def initialize(profile:)
      @profile = profile
    end

    def call
      build_result
    end

    private

    attr_reader :profile

    def build_result
      results =
        Timeout.timeout(TOTAL_DEADLINE, DeadlineExceeded) do
          profile.readiness_checks.map(&:call)
        end

      aggregate(results)
    rescue DeadlineExceeded
      aggregate([DependencyResult.new(kind: :deadline, status: :unready, message: "Deadline exceeded")])
    end

    def aggregate(results)
      CheckResult.new(
        check: :readiness,
        status: profile.status_policy.status_for(results),
        surface: profile.surface_label,
        dependencies: dependencies_for(results),
      )
    end

    def dependencies_for(results)
      results
        .group_by(&:kind)
        .transform_keys(&:to_s)
        .transform_values { |kind_results| kind_results.all?(&:ok?) ? "ok" : "failed" }
    end
  end

  # Startup probe: confirms boot/initialization completed.
  class StartupCheck
    def self.call(profile:)
      new(profile: profile).call
    end

    def initialize(profile:)
      @profile = profile
    end

    def call
      boot = Checks::Boot.new.call
      status = profile.status_policy.status_for([boot])

      CheckResult.new(check: :startup, status: status, surface: profile.surface_label)
    end

    private

    attr_reader :profile
  end

  # Aggregates liveness, readiness, and startup for the human-facing /health.
  class SnapshotCheck
    def self.call(profile:)
      new(profile: profile).call
    end

    def initialize(profile:)
      @profile = profile
    end

    def call
      sub_results = {
        liveness: LivenessCheck.call(profile: profile),
        readiness: ReadinessCheck.call(profile: profile),
        startup: StartupCheck.call(profile: profile),
      }

      CheckResult.new(
        check: :health,
        status: sub_results.values.all?(&:ok?) ? :ok : :unready,
        surface: profile.surface_label,
        dependencies: sub_results.transform_keys(&:to_s).transform_values(&:as_public_json),
      )
    end

    private

    attr_reader :profile
  end
end
