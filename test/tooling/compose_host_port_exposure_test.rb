# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

# Guards docs/operations/development-host-port-exposure.md.
#
# A `ports:` entry with no host address makes Podman bind 0.0.0.0, which places a development
# service on every host interface (LAN, Wi-Fi, Ethernet, Tailscale). This test reads the Compose
# files as text rather than running `podman compose config`, so it needs no container engine and
# runs in CI.
class ComposeHostPortExposureTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../..", __dir__)

  # Every tracked Compose file that participates in a development `up`, plus the opt-in
  # overlays. `.devcontainer/compose.override.yml` is where the Dev Container's own
  # publications live, so it belongs here too. The gitignored `compose.override.yaml` is
  # deliberately absent: it is optional, per-machine, and not present on a fresh clone.
  COMPOSE_FILES = %w(
    compose.yaml
    compose.override.yaml.example
    compose.remote-access.yaml
    .devcontainer/compose.override.yml
    podman/fdw-poc/compose.fdw-poc.yml
    docker/fdw-poc/compose.fdw-poc.yml
  ).freeze

  # Services that must never be reachable from the host, at any bind address. Each is consumed
  # only over a Compose network, by service name.
  NEVER_PUBLISHED_SERVICES = %w(primary replica valkey-cache valkey-rate-limit).freeze

  # An IPv4 or IPv6 loopback host address is the only accepted publication target.
  LOOPBACK_HOST_ADDRESSES = ["127.0.0.1", "::1"].freeze

  def test_every_published_port_binds_loopback
    offenders = each_published_port.reject { |entry| loopback?(entry.fetch(:published)) }

    assert_empty offenders.map { |entry| describe(entry) },
                 "Compose port publications must name an explicit loopback host address " \
                 "(127.0.0.1 or ::1). A bare \"PORT:PORT\" binds 0.0.0.0 and exposes the " \
                 "service to the LAN."
  end

  def test_datastore_services_publish_no_host_port
    offenders =
      each_published_port.select do |entry|
        NEVER_PUBLISHED_SERVICES.include?(entry.fetch(:service))
      end

    assert_empty offenders.map { |entry| describe(entry) },
                 "PostgreSQL and Valkey are container-only. Reach them as " \
                 "primary:5432, replica:5432, valkey-cache:6379, and valkey-rate-limit:6379."
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
  # and the AWS CLI can run from the host. It must never gain a container socket mount: that
  # would hand it full container-management rights under the invoking user, which is a far
  # larger grant than any port publication. See docs/operations/local-aws-fakecloud.md.
  def test_fakecloud_mounts_no_container_socket
    offenders =
      each_service.flat_map do |file, service, definition|
        Array(definition["volumes"]).filter_map do |mount|
          source = mount.is_a?(Hash) ? mount["source"].to_s : mount.to_s
          "#{file} #{service}: #{source}" if source.include?("docker.sock") || source.include?("podman.sock")
        end
      end

    assert_empty offenders,
                 "No Compose service may mount a container runtime socket. fakecloud serves the " \
                 "MSK control plane without one; handing it a socket to gain a real Kafka broker " \
                 "would grant it the invoking user's full container-management rights."
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
