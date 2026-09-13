# typed: false
# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"

# The registry that decides which OBJECT_STORAGE_BUCKET_* variables the development
# boot requires. Loaded directly because this test runs without the Rails environment.
require_relative "../../lib/object_storage_boundary"

class HostAuthorizationContractTest < Minitest::Test
  PRIVATE_ORIGIN_HOSTS = %w(
    auth.app.localhost:3000
    auth.com.localhost:3000
    auth.org.localhost:3000
    base.app.localhost:3000
    base.com.localhost:3000
    base.org.localhost:3000
    base.net.localhost:3000
    base.dev.localhost:3000
    wide.app.localhost:3000
    wide.app.localhost:3001
    wide.com.localhost:3000
    wide.com.localhost:3001
    wide.org.localhost:3000
    wide.org.localhost:3001
  ).freeze

  # PUBLIC_*_URL names the site a browser or app sees; PRIVATE_*_URL names the network-side
  # ingress the CDN/tunnel connects to (adr/public-private-url-boundaries.md). Development
  # is published through Cloudflare Tunnel behind Cloudflare Access, and cloudflared leaves
  # `Host` unmodified, so development Host Authorization must accept both families.
  BROWSER_FACING_SITE_HOSTS = %w(
    auth.umaxica.app
    auth.umaxica.com
    auth.umaxica.org
    www.umaxica.app
    www.umaxica.com
    www.umaxica.org
    edit.umaxica.org
    jp.umaxica.app
    jp.umaxica.com
    jp.umaxica.org
    www-jp.umaxica.app
    info.umaxica.app
    palm-jp.umaxica.app
    guid.umaxica.net
  ).freeze

  # The subprocess below boots RAILS_ENV=development, which resolves both Valkey
  # stores through a one-argument ENV.fetch. Neither is ever connected -- the
  # subprocess only drives ActionDispatch::HostAuthorization against a stub Rack
  # endpoint, and RedisCacheStore connects lazily -- but both names must be
  # present or the boot aborts before Host Authorization is built. Supplying them
  # here keeps the test from depending on whatever the surrounding shell or CI job
  # happens to export.
  DEVELOPMENT_BOOT_ENV = {
    "RAILS_ENV" => "development",
    "UMAXICA_ENV_FILE" => File.expand_path("../../.env.example", __dir__),
    "CACHE_REDIS_URL" => "redis://valkey-cache.invalid:6379/0",
    "RATE_LIMIT_REDIS_URL" => "redis://valkey-rate-limit.invalid:6379/0",
  }.freeze

  def test_effective_development_middleware_accepts_private_origins_and_rejects_an_unknown_host
    runner = <<~'RUBY'
      require "json"
      require "rack/mock"

      endpoint = ->(_env) { [200, { "content-type" => "text/plain" }, ["accepted"]] }
      middleware = ActionDispatch::HostAuthorization.new(
        endpoint,
        Rails.application.config.hosts,
        **Rails.application.config.host_authorization,
      )
      hosts = JSON.parse(ENV.fetch("HOST_AUTHORIZATION_TEST_HOSTS"))
      statuses = hosts.to_h do |host|
        response = Rack::MockRequest.new(middleware).get("/", "HTTP_HOST" => host)
        [host, response.status]
      end
      puts JSON.generate(statuses)
    RUBY
    hosts = PRIVATE_ORIGIN_HOSTS + ["evil.example.com"]
    stdout, stderr, status = Open3.capture3(
      child_object_storage_env.merge(
        DEVELOPMENT_BOOT_ENV,
        "HOST_AUTHORIZATION_TEST_HOSTS" => JSON.generate(hosts),
        "PRIVATE_AUTH_CORPORATE_URL" => "http://configured-auth.com.localhost:3000",
        "PRIVATE_AUTH_STAFF_URL" => "http://configured-auth.org.localhost:3000",
        "PRIVATE_BASE_NETWORK_URL" => "http://configured-base.net.localhost:3000",
        "PRIVATE_BASE_DEVELOPER_URL" => "http://configured-base.dev.localhost:3000",
      ),
      "bin/rails",
      "runner",
      runner,
    )

    assert_predicate status, :success?, stderr

    statuses = JSON.parse(stdout.lines.last)

    PRIVATE_ORIGIN_HOSTS.each do |host|
      assert_equal 200, statuses.fetch(host), "expected Host Authorization to accept #{host}"
    end
    assert_equal 403, statuses.fetch("evil.example.com")
  end

  def test_development_accepts_published_site_hosts_from_public_url_env_and_nothing_else
    runner = <<~'RUBY'
      require "json"
      require "rack/mock"

      endpoint = ->(_env) { [200, { "content-type" => "text/plain" }, ["accepted"]] }
      middleware = ActionDispatch::HostAuthorization.new(
        endpoint,
        Rails.application.config.hosts,
        **Rails.application.config.host_authorization,
      )
      hosts = JSON.parse(ENV.fetch("HOST_AUTHORIZATION_TEST_HOSTS"))
      statuses = hosts.to_h do |host|
        response = Rack::MockRequest.new(middleware).get("/", "HTTP_HOST" => host)
        [host, response.status]
      end
      puts JSON.generate(statuses)
    RUBY

    # Mirror the PUBLIC_* values compose.yaml sets for the development container, plus one
    # Umaxica-owned hostname that no PUBLIC_*_URL names. Admitting the published names must
    # not degrade into admitting the whole umaxica.* domain.
    unconfigured_site_host = "core-jp.umaxica.app"
    stdout, stderr, status = Open3.capture3(
      development_published_host_env(unconfigured_site_host),
      "bin/rails",
      "runner",
      runner,
    )

    assert_predicate status, :success?, stderr

    statuses = JSON.parse(stdout.lines.last)

    BROWSER_FACING_SITE_HOSTS.each do |host|
      assert_equal 200,
                   statuses.fetch(host),
                   "development Host Authorization must accept the published site host #{host}"
    end
    assert_equal 403, statuses.fetch(unconfigured_site_host)
    assert_equal 403, statuses.fetch("evil.example.com")
  end

  # `frontend` aliases that exist so something can DIAL the Rails container, never so
  # Rails can accept them as a Host. The Workers VPC Service names its target here; the
  # Host header on that path still comes from the Worker's `fetch()` URL, so these names
  # are deliberately absent from `config.hosts` and no `PUBLIC_*_URL` may name them.
  #
  # A `*.localhost` name cannot do this job: RFC 6761 makes glibc resolve anything under
  # `localhost.` to loopback before a container resolver is consulted.
  # See docs/operations/cloudflare-private-origin.md.
  ROUTING_ONLY_ALIASES = ["core-workers-vpc.internal"].freeze

  def test_development_compose_aliases_only_private_origins_and_configured_public_site_hosts
    compose = [File.read(File.expand_path("../../compose.yaml", __dir__)),
               File.read(File.expand_path("../../.devcontainer/compose.yaml", __dir__)),].join("\n")
    aliases_block = compose[/frontend:\n\s+aliases:\n((?:\s+(?:- \S+|#.*)\n)+)/, 1].to_s

    # Plain Minitest does not provide Rails' assert_not_empty assertion.
    # rubocop:disable Rails/RefuteMethods
    refute_empty aliases_block, "expected to find a frontend aliases block fronting Rails"
    # rubocop:enable Rails/RefuteMethods

    aliased_hosts = aliases_block.scan(/^\s+- (\S+)/).flatten
    env_file_paths =
      (compose.scan(/^\s+- (\.env[^\s]*)$/).flatten +
        %w(.env.devcontainer.example .env.example)).uniq
    env_files =
      env_file_paths.filter_map do |relative_path|
        path = File.expand_path(relative_path, File.expand_path("../..", __dir__))
        File.read(path) if File.file?(path)
      end
    configured_public_hosts =
      ([compose] + env_files).flat_map do |configuration|
        configuration.scan(/^\s*PUBLIC_[A-Z_]+_URL[:=]\s*(\S+)/).flatten
      end.map { |value| value.sub(%r{\Ahttps?://}, "") }

    aliased_hosts.each do |host|
      next if host.end_with?(".localhost")
      next if ROUTING_ONLY_ALIASES.include?(host)

      assert_includes configured_public_hosts,
                      host,
                      "#{host} is aliased to the Rails container, but no PUBLIC_*_URL in " \
                      "the Compose files or the env_file they name declares it, " \
                      "so development Host Authorization would reject it"
    end

    # The exemption above is only sound while these names really are routing-only. A
    # routing-only alias that also became an accepted Host would be admitting a hostname
    # no PUBLIC_*_URL declares, which is exactly what this test exists to prevent, so
    # assert the other half rather than trusting the exemption list.
    development_config = File.read(File.expand_path("../../config/environments/development.rb", __dir__))
    ROUTING_ONLY_ALIASES.each do |host|
      assert_includes aliased_hosts,
                      host,
                      "#{host} is exempted as routing-only but is no longer a frontend alias; " \
                      "drop it from ROUTING_ONLY_ALIASES"
      # rubocop:disable Rails/RefuteMethods
      refute_includes development_config,
                      host,
                      "#{host} is a Workers VPC routing target, not an origin Host. It must not " \
                      "appear in config.hosts: Cloudflare uses it only to pick the origin to dial, " \
                      "and the Host still comes from the Worker's fetch() URL"
      # rubocop:enable Rails/RefuteMethods
    end
  end

  def test_host_configuration_does_not_contain_a_catastrophic_broad_bypass
    development_config = File.read(File.expand_path("../../config/environments/development.rb", __dir__))
    production_config = File.read(File.expand_path("../../config/environments/production.rb", __dir__))

    # Plain Minitest does not provide Rails' assert_no_match assertion.
    # rubocop:disable Rails/RefuteMethods
    refute_match(/config\.hosts\.clear/, development_config)
    refute_match(/config\.hosts\.clear/, production_config)
    refute_match(/config\.hosts\s*<<\s*\/.+\//, development_config)
    refute_match(/config\.hosts\s*<<\s*\/.+\//, production_config)
    # rubocop:enable Rails/RefuteMethods
  end

  # Open3 hands the child our own environment, so whatever object-storage variables happen
  # to be set in this process - by the shell, by a .env, or by another test mid-flight -
  # decide whether the child boots. `development` resolves every registered storage
  # boundary at boot (config/initializers/shrine.rb), and that path is fail-fast: it
  # needs a complete S3-compatible configuration and refuses a partial one. Clearing the
  # set is not enough, because a cleared development boot then fails on the first missing
  # required variable. Supply a complete, self-contained fake configuration instead, so
  # the child boots deterministically regardless of the parent environment and this test
  # measures Host Authorization and nothing else. The values never reach the network:
  # each test only builds the middleware and drives it with Rack::MockRequest, and the
  # endpoint host is under RFC 2606's reserved .invalid TLD so it cannot resolve.
  SHARED_OBJECT_STORAGE_ENV = {
    "OBJECT_STORAGE_ENDPOINT" => "http://object-storage.invalid:4566",
    "OBJECT_STORAGE_REGION" => "us-east-1",
    "OBJECT_STORAGE_ACCESS_KEY_ID" => "test",
    "OBJECT_STORAGE_SECRET_ACCESS_KEY" => "test",
    "OBJECT_STORAGE_FORCE_PATH_STYLE" => "true",
    "CACHE_REDIS_URL" => "redis://127.0.0.1:6379/0",
    "RATE_LIMIT_REDIS_URL" => "redis://127.0.0.1:6380/0",
    # The _FILE variants take precedence over the plain names when set, so unset
    # them (nil) rather than leaving an inherited secret mount to win.
    "OBJECT_STORAGE_ACCESS_KEY_ID_FILE" => nil,
    "OBJECT_STORAGE_SECRET_ACCESS_KEY_FILE" => nil,
  }.freeze

  # Helpers, not cases. They must stay private: RuboCop's Minitest/TestMethodName
  # renames any PUBLIC method whose name contains "test" to a test_ prefix, which
  # would turn a helper into a silently passing case and break its callers.
  private

  # Derived from the registry rather than hand-listed. Registering a new boundary
  # adds a required OBJECT_STORAGE_BUCKET_<NAME> to the development boot, and a
  # hand-maintained list would go stale silently - the child would just die with a
  # KeyError that looks nothing like a Host Authorization failure.
  def child_object_storage_env
    buckets =
      ObjectStorage::Boundary.keys.to_h do |boundary|
        [ObjectStorage::Boundary.bucket_variable(boundary), "umaxica-#{boundary}-test"]
      end

    # Plain Minitest does not provide Rails' assert_not_empty assertion.
    # rubocop:disable Rails/RefuteMethods
    refute_empty buckets, "expected at least one registered object-storage boundary"
    # rubocop:enable Rails/RefuteMethods

    SHARED_OBJECT_STORAGE_ENV.merge(buckets)
  end

  def development_published_host_env(unconfigured_site_host)
    child_object_storage_env.merge(
      DEVELOPMENT_BOOT_ENV,
      "HOST_AUTHORIZATION_TEST_HOSTS" =>
        JSON.generate(BROWSER_FACING_SITE_HOSTS + [unconfigured_site_host, "evil.example.com"]),
      "PUBLIC_AUTH_SERVICE_URL" => "https://auth.umaxica.app",
      "PUBLIC_AUTH_CORPORATE_URL" => "https://auth.umaxica.com",
      "PUBLIC_AUTH_STAFF_URL" => "https://auth.umaxica.org",
      "PUBLIC_BASE_SERVICE_URL" => "https://www.umaxica.app",
      "PUBLIC_BASE_CORPORATE_URL" => "https://www.umaxica.com",
      "PUBLIC_BASE_STAFF_URL" => "https://www.umaxica.org",
      "PUBLIC_EDIT_STAFF_URL" => "https://edit.umaxica.org",
      "PUBLIC_CORE_SERVICE_URL" => "https://jp.umaxica.app",
      "PUBLIC_CORE_STAFF_URL" => "https://jp.umaxica.org",
      "PUBLIC_CORE_CORPORATE_URL" => "https://jp.umaxica.com",
      "PUBLIC_SIDE_SERVICE_URL" => "https://www-jp.umaxica.app",
      "PUBLIC_INFO_SERVICE_URL" => "https://info.umaxica.app",
      "PUBLIC_PALM_SERVICE_URL" => "https://palm-jp.umaxica.app",
      "PUBLIC_GUID_SERVICE_URL" => "https://guid.umaxica.net",
    )
  end
end
