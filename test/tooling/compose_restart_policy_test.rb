# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

# Plain Minitest::Test, like the other tooling guards: it reads Compose YAML and needs no Rails
# environment. That is why the assertions below are Minitest's `refute_*` rather than the
# `assert_not_*` forms RuboCop's Rails/RefuteMethods prefers -- those are ActiveSupport::TestCase
# additions and raise NoMethodError here.
# rubocop:disable Rails/RefuteMethods
class ComposeRestartPolicyTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../..", __dir__)
  COMPOSE_FILES = [
    "compose.yaml",
    "compose.override.yaml.example",
    ".devcontainer/compose.override.yml",
  ].freeze

  # The services a developer runs every session, and the only ones expected to
  # recover on their own. One-shot services deliberately stay on `restart: "no"`.
  # The observability group is on this list because it is no longer
  # profile-gated: a plain `up` starts all of it.
  RECOVERING_SERVICES = %w(
    alloy core fakecloud grafana loki prometheus primary replica tempo valkey-cache
    valkey-rate-limit
  ).freeze

  # Podman applies no backoff, so an unbounded policy turns a bad configuration into
  # ~2.8 container recreations a second. See
  # notes/implementation/2026-08-23-cloudflare-tunnel-restart-storm.md.
  UNBOUNDED_POLICIES = %w(always unless-stopped).freeze

  MAXIMUM_RESTART_ATTEMPTS = 5

  def test_no_service_carries_an_unbounded_restart_policy
    each_service do |compose_file, service, definition|
      policy = definition["restart"]
      next if policy.nil?

      refute_includes(
        UNBOUNDED_POLICIES,
        policy.to_s,
        "#{compose_file}: #{service} uses restart: #{policy}, which Podman retries without " \
        "backoff or limit; use on-failure:N so a failing container stops and stays visible",
      )
    end
  end

  def test_recovering_services_restart_within_a_bounded_attempt_budget
    each_recovering_service do |compose_file, service, definition|
      attempts = definition["restart"].to_s[/\Aon-failure:(\d+)\z/, 1]

      refute_nil(
        attempts,
        "#{compose_file}: #{service} must declare restart: on-failure:N so a transient failure " \
        "is ridden out and a real misconfiguration is left stopped, not restart: " \
        "#{definition["restart"].inspect}",
      )
      assert_includes(
        1..MAXIMUM_RESTART_ATTEMPTS,
        attempts.to_i,
        "#{compose_file}: #{service} allows #{attempts} restart attempts; keep the budget at " \
        "#{MAXIMUM_RESTART_ATTEMPTS} or fewer so a restart loop cannot saturate the host",
      )
    end
  end

  def test_recovering_services_cap_their_log_volume
    each_recovering_service do |compose_file, service, definition|
      logging = definition["logging"]

      # journald, Podman's rootless default, enforces no per-container size cap, and a
      # restart loop writes the same startup failure thousands of times.
      assert_equal(
        "json-file",
        logging.to_h["driver"],
        "#{compose_file}: #{service} must log through the size-capped json-file driver",
      )

      options = logging.to_h["options"].to_h

      %w(max-size max-file).each do |option|
        refute_nil(
          options[option],
          "#{compose_file}: #{service} sets no #{option}, so its log grows without bound",
        )
      end
    end
  end

  # `core` gates its start on these healthchecks. Removing one would silently turn its
  # `service_healthy` dependency into `service_started`, and nothing else asserts the
  # replica is actually streaming.
  def test_datastores_keep_a_healthcheck
    %w(primary replica valkey-cache valkey-rate-limit).each do |service|
      definition = base_compose.fetch("services").fetch(service)

      refute_nil(
        definition["healthcheck"],
        "compose.yaml: #{service} must keep a healthcheck; core depends on it being healthy",
      )
    end
  end

  # `core` deliberately has no healthcheck: the Dev Container runs `sleep infinity` and
  # Rails is started by hand, so any port probe would report unhealthy for most of a
  # session. Nothing here asserts one either way.

  private

  def base_compose
    @base_compose ||= load_compose("compose.yaml")
  end

  def load_compose(compose_file)
    YAML.safe_load_file(File.join(REPOSITORY_ROOT, compose_file), aliases: true)
  end

  def each_service
    COMPOSE_FILES.each do |compose_file|
      next unless File.exist?(File.join(REPOSITORY_ROOT, compose_file))

      load_compose(compose_file).fetch("services", {}).each do |service, definition|
        next unless definition.is_a?(Hash)

        yield compose_file, service, definition
      end
    end
  end

  def each_recovering_service
    RECOVERING_SERVICES.each do |service|
      yield "compose.yaml", service, base_compose.fetch("services").fetch(service)
    end
  end
end
# rubocop:enable Rails/RefuteMethods
