# typed: false
# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"

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
    jp.umaxica.app
    jp.umaxica.com
    jp.umaxica.org
    side-jp.umaxica.app
    info.umaxica.app
    palm-jp.umaxica.app
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
      cleared_object_storage_env.merge(
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

  def test_development_compose_aliases_only_private_origins_and_configured_public_site_hosts
    compose = File.read(File.expand_path("../../compose.yaml", __dir__))
    aliases_block = compose[/frontend:\n\s+aliases:\n((?:\s+(?:- \S+|#.*)\n)+)/, 1].to_s

    # Plain Minitest does not provide Rails' assert_not_empty assertion.
    # rubocop:disable Rails/RefuteMethods
    refute_empty aliases_block, "expected to find the core service's frontend aliases block"
    # rubocop:enable Rails/RefuteMethods

    aliased_hosts = aliases_block.scan(/^\s+- (\S+)/).flatten
    configured_public_hosts =
      compose.scan(/^\s+PUBLIC_[A-Z_]+_URL:\s*(\S+)/).flatten.map { |value| value.sub(%r{\Ahttps?://}, "") }

    aliased_hosts.each do |host|
      next if host.end_with?(".localhost")

      assert_includes configured_public_hosts,
                      host,
                      "compose.yaml aliases #{host} to core, but no PUBLIC_*_URL names it, " \
                      "so development Host Authorization would reject it"
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
  # decide whether the child boots. A partially configured set makes
  # `ObjectStorage::Environment.configured?` refuse to boot, by design. Clear the whole set
  # (nil unsets) so this test measures Host Authorization and nothing else.
  OBJECT_STORAGE_ENV_NAMES = %w(
    OBJECT_STORAGE_ENDPOINT OBJECT_STORAGE_REGION OBJECT_STORAGE_ACCESS_KEY_ID
    OBJECT_STORAGE_SECRET_ACCESS_KEY OBJECT_STORAGE_FORCE_PATH_STYLE
    OBJECT_STORAGE_ACCESS_KEY_ID_FILE OBJECT_STORAGE_SECRET_ACCESS_KEY_FILE
  ).freeze

  def cleared_object_storage_env
    OBJECT_STORAGE_ENV_NAMES.index_with(nil)
  end

  def development_published_host_env(unconfigured_site_host)
    cleared_object_storage_env.merge(
      DEVELOPMENT_BOOT_ENV,
      "HOST_AUTHORIZATION_TEST_HOSTS" =>
        JSON.generate(BROWSER_FACING_SITE_HOSTS + [unconfigured_site_host, "evil.example.com"]),
      "PUBLIC_AUTH_SERVICE_URL" => "https://auth.umaxica.app",
      "PUBLIC_AUTH_CORPORATE_URL" => "https://auth.umaxica.com",
      "PUBLIC_AUTH_STAFF_URL" => "https://auth.umaxica.org",
      "PUBLIC_BASE_SERVICE_URL" => "https://www.umaxica.app",
      "PUBLIC_BASE_CORPORATE_URL" => "https://www.umaxica.com",
      "PUBLIC_BASE_STAFF_URL" => "https://www.umaxica.org",
      "PUBLIC_CORE_SERVICE_URL" => "https://jp.umaxica.app",
      "PUBLIC_CORE_STAFF_URL" => "https://jp.umaxica.org",
      "PUBLIC_CORE_CORPORATE_URL" => "https://jp.umaxica.com",
      "PUBLIC_SIDE_SERVICE_URL" => "https://side-jp.umaxica.app",
      "PUBLIC_INFO_SERVICE_URL" => "https://info.umaxica.app",
      "PUBLIC_PALM_SERVICE_URL" => "https://palm-jp.umaxica.app",
    )
  end
end
