# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

# Guards adr/traces-and-metrics-routing-via-alloy.md: Alloy is the single observability ingestion
# gateway, and Grafana reads the three backends through provisioned datasources with stable UIDs.
#
# Host port exposure is a separate concern and lives in compose_host_port_exposure_test.rb. This
# file reads committed configuration only; it starts nothing.
class ObservabilityGatewayContractTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../..", __dir__)

  COMPOSE_FILES = %w(compose.yaml .devcontainer/compose.yaml).freeze
  OBSERVABILITY_SERVICES = %w(alloy tempo prometheus loki grafana).freeze

  # Grafana correlation (`tracesToLogsV2.datasourceUid`) points at a UID. Without an explicit
  # `uid:` Grafana generates one per installation, so the reference resolves on the machine that
  # wrote it and silently breaks everywhere else.
  EXPECTED_DATASOURCE_UIDS = { "Loki" => "loki", "Tempo" => "tempo", "Prometheus" => "prometheus" }.freeze

  # Every collector or log shipper that the ADR retires or forbids. Stacking a second agent beside
  # Alloy reintroduces the duplicated-role problem the ADR removed.
  FORBIDDEN_AGENT_SERVICES = %w(otel-collector otelcol opentelemetry-collector promtail fluent-bit fluentbit vector).freeze

  def test_no_retired_or_duplicate_collector_service_exists
    offenders =
      each_service.filter_map do |file, service, _definition|
        "#{file}: #{service}" if FORBIDDEN_AGENT_SERVICES.include?(service)
      end

    assert_empty offenders,
                 "Alloy is the only observability agent. Retired: `otel-collector`. Forbidden " \
                 "additions: Promtail, Fluent Bit, Vector, or a second OpenTelemetry Collector."
  end

  def test_observability_services_stay_on_the_observability_network
    offenders =
      each_service.filter_map do |file, service, definition|
        next unless OBSERVABILITY_SERVICES.include?(service)

        networks = network_names(definition)
        "#{file} #{service}: #{networks.inspect}" unless networks == ["observability"]
      end

    assert_empty offenders,
                 "Observability services attach to `observability` only. Attaching Grafana to " \
                 "`frontend` would place it behind the Cloudflare Tunnel origins."
  end

  def test_every_grafana_datasource_declares_a_deterministic_uid
    datasources.each do |datasource|
      name = datasource["name"]
      expected = EXPECTED_DATASOURCE_UIDS.fetch(name) { flunk("Unexpected provisioned datasource #{name.inspect}") }

      assert_equal expected, datasource["uid"],
                   "#{name} must declare a deterministic UID so cross-datasource references resolve."
    end

    assert_equal EXPECTED_DATASOURCE_UIDS.keys.sort, datasources.map { |d| d["name"] }.sort
  end

  def test_datasource_cross_references_resolve_to_a_provisioned_uid
    known = datasources.map { |datasource| datasource["uid"] }
    referenced = referenced_datasource_uids(datasources)

    refute_empty referenced, "Tempo keeps a trace-to-logs correlation into Loki."
    assert_empty referenced - known,
                 "A datasource reference names a UID no provisioned datasource declares."
  end

  # Rails must not hold a second export path. Only Alloy talks to Tempo, Prometheus and Loki.
  def test_alloy_is_the_only_writer_to_the_storage_backends
    config = File.read(File.join(REPOSITORY_ROOT, "podman/alloy/config.alloy"))

    assert_includes config, "tempo:4317", "Alloy exports traces to Tempo over OTLP/gRPC."
    assert_includes config, "http://prometheus:9090/api/v1/write", "Alloy remote-writes metrics."
    assert_includes config, "http://loki:3100/loki/api/v1/push", "Alloy pushes logs to Loki."

    initializer = File.read(File.join(REPOSITORY_ROOT, "config/initializers/opentelemetry.rb"))

    %w(tempo: prometheus: loki:).each do |backend|
      refute_includes initializer, backend,
                      "Rails exports to Alloy only; a direct backend endpoint bypasses the gateway " \
                      "and its redaction stage."
    end
  end

  # The agent-side half of the two-stage redaction in the ADR. Losing it leaves the in-process
  # scrubber as the only barrier between an unfiltered instrumentation and storage.
  def test_alloy_keeps_the_agent_side_redaction_stage
    config = File.read(File.join(REPOSITORY_ROOT, "podman/alloy/config.alloy"))

    assert_includes config, 'otelcol.processor.attributes "redact"'
    assert_includes config, ".*(authorization|cookie).*"
    assert_includes config, "^(token|access_token|id_token|refresh_token)$"
  end

  # An unbounded local volume is a misconfiguration under the ADR. Tempo and Prometheus already
  # carry 24h; logs must not be the exception.
  def test_every_storage_backend_declares_bounded_retention
    tempo = YAML.safe_load_file(File.join(REPOSITORY_ROOT, "podman/tempo/tempo.yaml"))

    assert_equal "24h", tempo.dig("compactor", "compaction", "block_retention")

    prometheus_command = compose_service("compose.yaml", "prometheus").fetch("command")

    assert_includes prometheus_command, "--storage.tsdb.retention.time=24h"

    # `schema_config` carries a bare date, which safe_load rejects unless Date is permitted.
    loki = YAML.safe_load_file(File.join(REPOSITORY_ROOT, "podman/loki/loki.yaml"), permitted_classes: [Date])

    assert_equal "24h", loki.dig("limits_config", "retention_period")
    assert loki.dig("compactor", "retention_enabled"),
           "Loki keeps chunks forever unless the compactor is allowed to enforce the retention period."
  end

  private

  def datasources
    @datasources ||=
      YAML.safe_load_file(
        File.join(REPOSITORY_ROOT, "podman/grafana/provisioning/datasources/datasources.yml"),
      ).fetch("datasources")
  end

  # `datasourceUid` can sit at any depth of a datasource's jsonData, so walk rather than reach for
  # the one key tracesToLogsV2 happens to use today.
  def referenced_datasource_uids(node)
    case node
    when Hash
      node.flat_map { |key, value| (key == "datasourceUid") ? [value] : referenced_datasource_uids(value) }
    when Array
      node.flat_map { |value| referenced_datasource_uids(value) }
    else
      []
    end
  end

  def network_names(definition)
    networks = definition["networks"]
    return networks.keys if networks.is_a?(Hash)

    Array(networks)
  end

  def compose_service(file, name)
    load_compose(file).fetch("services").fetch(name)
  end

  def each_service
    COMPOSE_FILES.flat_map do |file|
      (load_compose(file)["services"] || {}).filter_map { |name, definition| [file, name, definition] if definition }
    end
  end

  def load_compose(relative_path)
    path = File.join(REPOSITORY_ROOT, relative_path)
    return {} unless File.exist?(path)

    YAML.safe_load_file(path, aliases: true) || {}
  end
end
