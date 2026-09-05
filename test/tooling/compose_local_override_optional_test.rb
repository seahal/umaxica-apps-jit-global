# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "yaml"

# The local-override contract.
#
#   compose.yaml                       the complete standard environment
#   .devcontainer/compose.override.yml tracked; the Dev Container's own overlay
#   compose.override.yaml              optional, gitignored, per developer/machine
#   compose.override.yaml.example      tracked documentation, never required
#
# A fresh `git clone` plus a container engine must be enough to resolve the Compose
# configuration and to open the Dev Container. Nothing may depend on a file the clone
# does not contain, and nothing may depend on a variable the machine has not set.
#
# This reads files as text/JSON, so it needs no container engine and runs in CI.
#
# Plain Minitest::Test, like the other tooling guards, so the assertions below are Minitest's
# `refute_*` rather than the `assert_not_*` forms RuboCop's Rails/RefuteMethods prefers -- those
# are ActiveSupport::TestCase additions and raise NoMethodError here.
# rubocop:disable Rails/RefuteMethods
class ComposeLocalOverrideOptionalTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../..", __dir__)

  # The Compose files a standard development `up` resolves. The optional
  # `compose.override.yaml` is absent by design, and the `fdw-poc` experiment files are
  # excluded on purpose: they are never merged into this project, are invoked explicitly
  # with their own `-f`, and are allowed to demand their own variables.
  STANDARD_COMPOSE_FILES = %w(
    compose.yaml
    compose.override.yaml.example
    .devcontainer/compose.override.yml
  ).freeze

  # Files the Dev Container loads, and which therefore must resolve on a clean checkout.
  DEVCONTAINER_CONFIG = ".devcontainer/devcontainer.json"

  def test_devcontainer_config_is_strict_json
    # The Dev Containers CLI tolerates comments; other consumers and hand-editing do not,
    # and a stray trailing comma is exactly the kind of thing that only fails on someone
    # else's machine. Parse the comment-stripped text with a strict parser.
    assert_kind_of Hash, devcontainer_configuration
  end

  def test_every_devcontainer_compose_file_is_tracked
    tracked = git_tracked_files

    entries = devcontainer_configuration.fetch("dockerComposeFile")
    entries = [entries] if entries.is_a?(String)

    refute_empty entries

    entries.each do |entry|
      # Entries are relative to devcontainer.json, which lives in .devcontainer/.
      path = File.expand_path(entry, File.join(REPOSITORY_ROOT, ".devcontainer"))
      relative = path.delete_prefix("#{REPOSITORY_ROOT}/")

      assert_path_exists path, "#{entry} is referenced by devcontainer.json but missing"
      assert_includes tracked, relative,
                      "#{entry} is referenced by devcontainer.json but is not tracked by git, " \
                      "so it does not exist on a fresh clone"
    end
  end

  def test_no_tracked_compose_file_requires_a_host_variable
    # `${VAR:?}` is the fresh-clone breaker that is easy to miss: Compose interpolates
    # every listed file in full whichever service is named, so one required variable stops
    # `devcontainer up` on a machine that never runs that service. Opt-in belongs to a
    # `profiles:` entry instead, which is what `cloudflare-tunnel-edge` uses.
    STANDARD_COMPOSE_FILES.each do |relative_path|
      directives = directives_of(relative_path)

      refute_match(
        /\$\{[^}]+:\?/, directives,
        "#{relative_path} uses a required ${VAR:?} interpolation, which breaks a fresh clone",
      )
    end
  end

  def test_the_local_override_is_not_tracked
    tracked = git_tracked_files

    refute_includes tracked, "compose.override.yaml",
                    "the developer-local override must stay out of git"
    refute_includes tracked, "compose.custom.yaml",
                    "compose.custom.yaml is retired and must not come back"

    gitignore = File.read(File.join(REPOSITORY_ROOT, ".gitignore"))

    assert_match(/^\/compose\.override\.yaml$/, gitignore)
  end

  def test_the_example_matches_the_current_schema
    # The example is documentation, and a stale example is worse than none: it must parse,
    # and it must only name services that still exist.
    example = YAML.safe_load_file(
      File.join(REPOSITORY_ROOT, "compose.override.yaml.example"), aliases: true,
    )
    base = YAML.safe_load_file(File.join(REPOSITORY_ROOT, "compose.yaml"), aliases: true)

    assert_equal base.fetch("name"), example.fetch("name"),
                 "a divergent project name forks the volume set"

    example.fetch("services", {}).each_key do |service|
      assert_includes base.fetch("services").keys, service,
                      "the example override names a service compose.yaml does not define"
    end
  end

  def test_the_primary_tunnel_connector_starts_with_the_devcontainer_stack
    # The Dev Containers CLI starts every unprofiled service in the merged Compose
    # files. Gating the primary connector behind `profiles: [tunnel]` kept
    # `devcontainer up` from creating the sidecar at all, even when
    # CLOUDFLARED_TOKEN was set. The empty-token case is already bounded by
    # `${CLOUDFLARED_TOKEN:-}` plus `restart: on-failure:3`.
    services = YAML.safe_load_file(
      File.join(REPOSITORY_ROOT, "compose.yaml"),
      aliases: true,
    ).fetch("services")
    connector = services.fetch("cloudflare-tunnel")

    refute connector.key?("profiles"),
           "cloudflare-tunnel must start with a plain compose up / Dev Container lifecycle, " \
           "not sit behind a profile the CLI never enables"
    refute connector.key?("depends_on"),
           "a Compose dependency becomes a container dependency under Podman and breaks " \
           "the Dev Containers CLI's --remove-existing-container"
  end

  def test_the_tunnel_connector_keeps_the_process_alive_across_transport_loss
    # Pinning `--protocol quic` disables the documented HTTP/2 fallback. After a
    # laptop sleep or UDP 7844 blip, cloudflared can drain every HA connection and
    # exit 0 ("no more connections active and exiting"). `restart: on-failure`
    # does not recreate a container that exited 0, which is the "tunnel dies and
    # stays dead" report. `auto` still prefers QUIC (Workers VPC allows `auto` or
    # `quic`) and falls back instead of exiting.
    # https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/run-parameters/#protocol
    # https://developers.cloudflare.com/workers-vpc/configuration/tunnel/
    command = YAML.safe_load_file(
      File.join(REPOSITORY_ROOT, "compose.yaml"),
      aliases: true,
    ).fetch("services").fetch("cloudflare-tunnel").fetch("command")

    assert_includes command, "--protocol auto"
    assert_includes command, "--no-autoupdate"
    refute_includes command, "--protocol quic"
  end

  def test_the_edge_tunnel_connector_is_opt_in_by_profile
    services = YAML.safe_load_file(
      File.join(REPOSITORY_ROOT, "compose.yaml"),
      aliases: true,
    ).fetch("services")
    connector = services.fetch("cloudflare-tunnel-edge")

    assert_includes connector.fetch("profiles"), "tunnel-edge"
    refute connector.key?("depends_on"),
           "a Compose dependency becomes a container dependency under Podman and breaks " \
           "the Dev Containers CLI's --remove-existing-container"
  end

  def test_the_tunnel_connectors_differ_only_in_profile_and_token
    # The second connector merges the first, so the pinned cloudflared release, the QUIC
    # command, the `frontend` attachment, and the crash-loop caps cannot drift apart. This
    # asserts the merge is still in place after any edit to either service.
    services = YAML.safe_load_file(
      File.join(REPOSITORY_ROOT, "compose.yaml"),
      aliases: true,
    ).fetch("services")

    primary = services.fetch("cloudflare-tunnel")
    edge = services.fetch("cloudflare-tunnel-edge")

    assert_equal %w(environment profiles),
                 (primary.keys | edge.keys).reject { |key| primary[key] == edge[key] }.sort,
                 "the two connectors must share every setting except their profile and token"
    assert_equal({ "TUNNEL_TOKEN" => "${CLOUDFLARED_TOKEN:-}" }, primary.fetch("environment"))
    assert_equal({ "TUNNEL_TOKEN" => "${CLOUDFLARED_EDGE_TOKEN:-}" }, edge.fetch("environment"))
  end

  private

  def devcontainer_configuration
    source = File.read(File.join(REPOSITORY_ROOT, DEVCONTAINER_CONFIG))
    JSON.parse(source.gsub(%r{^\s*//.*$}, ""))
  end

  def git_tracked_files
    @git_tracked_files ||= IO.popen(["git", "-C", REPOSITORY_ROOT, "ls-files"], &:read).split("\n")
  end

  # Compose text with its comment lines removed, so prose about a rule cannot satisfy or
  # violate the rule.
  def directives_of(relative_path)
    File.read(File.join(REPOSITORY_ROOT, relative_path))
      .lines
      .reject { |line| line.lstrip.start_with?("#") }
      .join
  end
end
# rubocop:enable Rails/RefuteMethods
