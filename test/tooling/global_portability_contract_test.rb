# frozen_string_literal: true

# rubocop:disable Rails/RefuteMethods
require "json"
require "minitest/autorun"
require "yaml"

# Repository-level contract for the Global portability brief. This test intentionally reads
# configuration as text/data and does not require a container engine, network, or credentials.
class GlobalPortabilityContractTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  REQUIRED_ENV = %w(
    BINDING PORT BRAND_NAME
    POSTGRESQL_HOST POSTGRESQL_PORT POSTGRESQL_USER POSTGRESQL_PASSWORD
    POSTGRESQL_PUBLISHING_PUB POSTGRESQL_PUBLISHING_SUB
    POSTGRESQL_QUEUE_PUB POSTGRESQL_STORAGE_PUB POSTGRESQL_PRIMARY_PUB
    CACHE_REDIS_URL RATE_LIMIT_REDIS_URL OBJECT_STORAGE_ENDPOINT
    PUBLIC_AUTH_SERVICE_URL PUBLIC_BASE_SERVICE_URL PRIVATE_AUTH_SERVICE_URL PRIVATE_BASE_SERVICE_URL
    VITE_RUBY_PACKAGE_MANAGER
  ).freeze

  def test_non_secret_host_contract_is_complete_and_the_container_variant_is_tracked
    host = parse_env(".env.example")
    container = parse_env(".env.devcontainer.example")

    REQUIRED_ENV.each { |name| assert host.key?(name), "host contract misses #{name}" }
    assert_equal "bun", host.fetch("VITE_RUBY_PACKAGE_MANAGER")
    assert_equal "127.0.0.1", host.fetch("POSTGRESQL_PUBLISHING_PUB")
    assert_equal "primary", container.fetch("POSTGRESQL_PUBLISHING_PUB")
    assert_equal "replica", container.fetch("POSTGRESQL_PUBLISHING_SUB")
    assert_equal "redis://valkey-cache:6379/0", container.fetch("CACHE_REDIS_URL")
    assert_equal "http://fakecloud:4566", container.fetch("OBJECT_STORAGE_ENDPOINT")
  end

  def test_environment_contract_contains_no_production_secret_material
    %w(.env.example .env.devcontainer.example).each do |path|
      source = File.read(File.join(ROOT, path))

      refute_match(/RAILS_MASTER_KEY|SECRET_KEY_BASE|BEGIN (?:RSA|OPENSSH|EC) PRIVATE KEY/, source)
      refute_match(%r{AKIA[0-9A-Z]{16}}, source)
      refute_match(%r{https?://[^\s/:]+:[^\s/@]+@}, source)
    end
  end

  def test_compose_defines_topology_without_inline_application_configuration
    root = load_yaml("compose.yaml")
    devcontainer = load_yaml(".devcontainer/compose.yaml")
    core = devcontainer.fetch("services").fetch("core")

    refute_includes root.fetch("services"), "core"
    assert_equal [".env.devcontainer.example"], core.fetch("env_file")
    refute core.key?("environment"), "application configuration belongs to the shared env contract"
    assert_equal "127.0.0.1:${POSTGRESQL_PRIMARY_HOST_PORT:-5432}:5432",
                 root.fetch("services").fetch("primary").fetch("ports").first
    assert_equal "127.0.0.1:${POSTGRESQL_REPLICA_HOST_PORT:-5433}:5432",
                 root.fetch("services").fetch("replica").fetch("ports").first
  end

  def test_devcontainer_and_frontend_toolchain_use_tracked_portable_inputs
    devcontainer = JSON.parse(File.read(File.join(ROOT, ".devcontainer/devcontainer.json")).gsub(/^\s*\/\/.*$/, ""))
    package = JSON.parse(File.read(File.join(ROOT, "package.json")))
    compose = File.read(File.join(ROOT, ".devcontainer/compose.yaml"))

    assert_equal ["../compose.yaml", "./compose.yaml"], devcontainer.fetch("dockerComposeFile")
    assert_equal "bun@1.4.0", package.fetch("packageManager")
    assert_includes compose, "target: \"/home/global/.bun\""
    assert_path_exists File.join(ROOT, ".env.example")
    assert_path_exists File.join(ROOT, ".env.devcontainer.example")
  end

  def test_local_environment_loader_never_overrides_explicit_process_values
    source = File.read(File.join(ROOT, "lib/local_environment.rb"))

    assert_includes source, "!ENV.key?(name)"
    assert_includes source, "RAILS_ENV\"] == \"production\""
    assert_includes File.read(File.join(ROOT, ".gitignore")), ".env"
  end

  private

  def parse_env(relative_path)
    File.readlines(File.join(ROOT, relative_path)).filter_map do |line|
      next if line.strip.empty? || line.lstrip.start_with?("#")

      name, value = line.strip.split("=", 2)
      [name, value]
    end.to_h
  end

  def load_yaml(relative_path)
    YAML.safe_load_file(File.join(ROOT, relative_path), aliases: true)
  end
end
