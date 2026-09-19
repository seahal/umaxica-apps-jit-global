# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

# Guards docs/operations/development-host-port-exposure.md.
#
# A `ports:` entry with no host address makes Podman bind 0.0.0.0, which places a development
# service on every host interface (LAN, Wi-Fi, Ethernet, Tailscale). This test reads the Compose
# files as text rather than running `podman compose config`, so it needs no container engine and
# runs in CI. It is a contract test over committed configuration, not a test of environment
# construction (.agents/harnesses/rules/project/no-environment-tests.mdc).
class ComposeHostPortExposureTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../..", __dir__)

  # Every tracked Compose file that participates in a development `up`. The gitignored
  # `compose.override.yaml` is deliberately absent: it is optional, per-machine, and not present
  # on a fresh clone.
  COMPOSE_FILES = %w(
    compose.yaml
    .devcontainer/compose.yaml
  ).freeze

  # Services that must never be reachable from the host, at any bind address. Each is consumed
  # only over a Compose network, by service name. Tempo, Prometheus and Loki are backends of the
  # Alloy gateway: Grafana queries them over `observability`, and nothing on the host dials them.
  CONTAINER_ONLY_SERVICES = %w(tempo prometheus loki).freeze

  # An IPv4 or IPv6 loopback host address is the only accepted publication target.
  LOOPBACK_HOST_ADDRESSES = ["127.0.0.1", "::1"].freeze

  # The two host-visible observability listeners, and the only ones. Grafana is a browser UI for
  # the development machine itself; Alloy's 4318 is the OTLP/HTTP ingress that host-native Rails
  # exports to. Alloy's management UI (12345) and OTLP/gRPC (4317) stay container-only.
  GRAFANA_DEFAULT_HOST_PORT = "13000"
  ALLOY_OTLP_HTTP_DEFAULT_HOST_PORT = "4318"

  def test_every_published_port_binds_loopback
    offenders = each_published_port.reject { |entry| loopback?(entry.fetch(:published)) }

    assert_empty offenders.map { |entry| describe(entry) },
                 "Compose port publications must name an explicit loopback host address " \
                 "(127.0.0.1 or ::1). A bare \"PORT:PORT\" binds 0.0.0.0 and exposes the " \
                 "service to the LAN."
  end

  def test_backend_observability_services_have_no_host_publication
    offenders =
      each_published_port.select { |entry| CONTAINER_ONLY_SERVICES.include?(entry.fetch(:service)) }

    assert_empty offenders.map { |entry| describe(entry) },
                 "Tempo, Prometheus and Loki are reached only by Alloy and Grafana over the " \
                 "`observability` network. Publishing one to the host adds an ingestion path " \
                 "that bypasses the single Alloy gateway."
  end

  def test_grafana_publishes_only_loopback_13000
    entries = published_ports_for("grafana")

    assert_equal 1, entries.length, "Grafana publishes exactly one host port; found #{entries.inspect}"

    entry = entries.first

    assert_equal "127.0.0.1", entry.fetch(:published),
                 "The Grafana UI is for the development machine only and must not reach the LAN, " \
                 "Cloudflare, or Tailscale."
    assert_equal GRAFANA_DEFAULT_HOST_PORT, default_host_port(entry),
                 "Host 3000/3001 belong to host-native and Dev Container Rails; Grafana takes 13000."
    assert_equal "3000", container_port(entry), "Grafana's container port stays the upstream default."
  end

  def test_alloy_publishes_only_the_loopback_otlp_http_receiver
    entries = published_ports_for("alloy")

    assert_equal 1, entries.length, "Alloy publishes exactly one host port; found #{entries.inspect}"

    entry = entries.first

    assert_equal "127.0.0.1", entry.fetch(:published),
                 "The OTLP ingress accepts host-native Rails only; a LAN-reachable receiver would " \
                 "accept telemetry from any machine on the network."
    assert_equal ALLOY_OTLP_HTTP_DEFAULT_HOST_PORT, default_host_port(entry)
    assert_equal "4318", container_port(entry),
                 "Only OTLP/HTTP is published. The management UI (12345) and OTLP/gRPC (4317) " \
                 "stay on the `observability` network."
  end

  def test_no_service_uses_host_networking
    offenders =
      each_service.filter_map do |file, service, definition|
        "#{file} #{service}: network_mode: host" if definition["network_mode"] == "host"
      end

    assert_empty offenders,
                 "`network_mode: host` bypasses port publication entirely and puts every " \
                 "listener on the host's interfaces."
  end

  # fakecloud is the one AWS-facing service that is published, and only to loopback so OpenTofu
  # and the AWS CLI can run from the host. No service may gain a container socket mount: that
  # would hand it full container-management rights under the invoking user, which is a far
  # larger grant than any port publication.
  def test_no_service_mounts_a_container_socket
    offenders =
      each_service.flat_map do |file, service, definition|
        Array(definition["volumes"]).filter_map do |mount|
          source = mount.is_a?(Hash) ? mount["source"].to_s : mount.to_s
          "#{file} #{service}: #{source}" if source.include?("docker.sock") || source.include?("podman.sock")
        end
      end

    assert_empty offenders, "No Compose service may mount a container runtime socket."
  end

  private

  def each_service
    COMPOSE_FILES.flat_map do |file|
      services = load_compose(file)["services"] || {}
      services.filter_map { |name, definition| [file, name, definition] if definition }
    end
  end

  def each_published_port
    each_service.flat_map do |file, service, definition|
      Array(definition["ports"]).map do |port|
        { file: file, service: service, entry: port, published: published_host_address(port) }
      end
    end
  end

  def published_ports_for(service)
    each_published_port.select { |entry| entry.fetch(:service) == service }
  end

  # Compose accepts both the short string form ("127.0.0.1:3000:3000") and the long mapping form
  # ({"target" => 3000, "published" => "3000", "host_ip" => "127.0.0.1"}). Anything this method
  # cannot resolve to a host address is reported rather than assumed safe.
  def published_host_address(port)
    return port["host_ip"].to_s if port.is_a?(Hash)

    text = port.to_s
    return text[/\A\[([^\]]+)\]:/, 1] if text.start_with?("[")

    segments = text.split(":")
    (segments.length >= 3) ? segments.first : ""
  end

  # The host side of a mapping, with any `${VAR:-default}` resolved to its default. The default is
  # what a fresh clone gets, so it is the value this contract pins.
  def default_host_port(entry)
    port = entry.fetch(:entry)
    return interpolate(port["published"].to_s) if port.is_a?(Hash)

    # Interpolate first: `${GRAFANA_HOST_PORT:-13000}` carries a colon of its own,
    # so splitting the raw string cuts the mapping in the wrong place.
    interpolate(port.to_s).split(":")[-2].to_s
  end

  def container_port(entry)
    port = entry.fetch(:entry)
    return port["target"].to_s if port.is_a?(Hash)

    interpolate(port.to_s).split(":").last
  end

  def interpolate(text)
    text.gsub(/\$\{[A-Z0-9_]+:-([^}]*)\}/, '\1')
  end

  def loopback?(address)
    LOOPBACK_HOST_ADDRESSES.include?(address)
  end

  def describe(entry)
    "#{entry.fetch(:file)} #{entry.fetch(:service)}: #{entry.fetch(:entry).inspect}"
  end

  def load_compose(relative_path)
    path = File.join(REPOSITORY_ROOT, relative_path)
    return {} unless File.exist?(path)

    # Compose interpolation (`${VAR:-default}`) is opaque to YAML but always sits inside a scalar,
    # so plain parsing is enough to read the structure. Aliases must be expanded: the second
    # Cloudflare connector merges the first, and an unexpanded service would hide whatever it
    # inherits from this contract. The inputs are tracked repository files, so there is no
    # untrusted anchor to guard against.
    YAML.safe_load_file(path, aliases: true) || {}
  end
end
