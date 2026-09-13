# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "ostruct"

class SideRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "side app route contract accepts the configured public host" do
    with_boot_config(side_service_host: "side-jp.example.test") do
      recognized = Rails.application.routes.recognize_path(
        "http://side-jp.example.test/",
        method: :get,
      )

      assert_equal "side/app/roots", recognized[:controller]
      assert_equal "index", recognized[:action]
    end
  ensure
    Rails.application.reload_routes!
  end

  test "side com route contract accepts the configured public host" do
    with_boot_config(side_corporate_host: "side-jp.example.test") do
      recognized = Rails.application.routes.recognize_path(
        "http://side-jp.example.test/",
        method: :get,
      )

      assert_equal "side/com/roots", recognized[:controller]
      assert_equal "index", recognized[:action]
    end
  ensure
    Rails.application.reload_routes!
  end

  test "side org route contract accepts the configured public host" do
    with_boot_config(side_staff_host: "side-jp.example.test") do
      recognized = Rails.application.routes.recognize_path(
        "http://side-jp.example.test/",
        method: :get,
      )

      assert_equal "side/org/roots", recognized[:controller]
      assert_equal "index", recognized[:action]
    end
  ensure
    Rails.application.reload_routes!
  end

  # The Side chrome renders theme and cookie-consent controls, so Side must own the web preference
  # authority those controls POST to -- otherwise the request 404s and the choice is never
  # persisted (it only changes the current page).
  test "side owns a web preference authority for its chrome theme and cookie controls" do
    with_boot_config(
      side_service_host: "side-jp.example.test",
      side_corporate_host: "side-com.example.test",
      side_staff_host: "side-org.example.test",
    ) do
      {
        "http://side-jp.example.test/web/v0/theme" => "side/app/web/v0/themes",
        "http://side-jp.example.test/web/v0/cookie" => "side/app/web/v0/cookies",
        "http://side-com.example.test/web/v0/theme" => "side/com/web/v0/themes",
        "http://side-org.example.test/web/v0/theme" => "side/org/web/v0/themes",
      }.each do |url, controller|
        recognized = Rails.application.routes.recognize_path(url, method: :patch)

        assert_equal controller, recognized[:controller], url
        assert_equal "update", recognized[:action], url
      end
    end
  ensure
    Rails.application.reload_routes!
  end

  private

  class BootConfig
    def initialize(hosts)
      @hosts = hosts
    end

    def fetch(key)
      return @hosts if key == :hosts

      raise KeyError, key.to_s
    end
  end

  def with_boot_config(side_service_host: ENV.fetch("PUBLIC_SIDE_SERVICE_URL"),
                       side_corporate_host: ENV.fetch("PUBLIC_SIDE_CORPORATE_URL"),
                       side_staff_host: ENV.fetch("PUBLIC_SIDE_STAFF_URL"))
    hosts = side_route_boot_hosts(side_service_host, side_corporate_host, side_staff_host)

    Rails.configuration.x.stub(:boot_config, BootConfig.new(hosts)) do
      Rails.application.reload_routes!
      yield
    ensure
      Rails.application.reload_routes!
    end
  end

  def side_route_boot_hosts(side_service_host, side_corporate_host, side_staff_host)
    OpenStruct.new(
      **side_route_identity_hosts,
      **side_route_product_hosts(side_service_host, side_corporate_host, side_staff_host),
    )
  end

  def side_route_identity_hosts
    {
      auth_service: OpenStruct.new(host: ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")),
      auth_corporate: OpenStruct.new(host: ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost")),
      auth_staff: OpenStruct.new(host: ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost")),
      acme_service: OpenStruct.new(host: ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost")),
      acme_corporate: OpenStruct.new(host: ENV.fetch("PRIVATE_BASE_CORPORATE_URL", "www.com.localhost")),
      acme_staff: OpenStruct.new(host: ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost")),
      sign_service: OpenStruct.new(host: ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")),
      sign_corporate: OpenStruct.new(host: ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost")),
      sign_staff: OpenStruct.new(host: ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost")),
    }
  end

  def side_route_product_hosts(side_service_host, side_corporate_host, side_staff_host)
    {
      core_service: OpenStruct.new(
        host: ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost")),
      ),
      core_corporate: OpenStruct.new(
        host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL", ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost")),
      ),
      core_staff: OpenStruct.new(
        host: ENV.fetch("PUBLIC_CORE_STAFF_URL", ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost")),
      ),
      base_service: OpenStruct.new(host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")),
      base_corporate: OpenStruct.new(host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")),
      base_staff: OpenStruct.new(host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")),
      palm_service: OpenStruct.new(host: ENV.fetch("PUBLIC_PALM_SERVICE_URL")),
      palm_corporate: OpenStruct.new(host: Rails.configuration.x.boot_config.fetch(:hosts).palm_corporate.host),
      palm_staff: OpenStruct.new(host: Rails.configuration.x.boot_config.fetch(:hosts).palm_staff.host),
      help_service: OpenStruct.new(host: ENV.fetch("PRIVATE_HELP_SERVICE_URL")),
      help_corporate: OpenStruct.new(host: ENV.fetch("PRIVATE_HELP_CORPORATE_URL")),
      help_staff: OpenStruct.new(host: ENV.fetch("PRIVATE_HELP_STAFF_URL")),
      info_service: OpenStruct.new(host: ENV.fetch("PRIVATE_INFO_SERVICE_URL")),
      info_corporate: OpenStruct.new(host: ENV.fetch("PRIVATE_INFO_CORPORATE_URL")),
      info_staff: OpenStruct.new(host: ENV.fetch("PRIVATE_INFO_STAFF_URL")),
      side_service: OpenStruct.new(host: side_service_host),
      side_corporate: OpenStruct.new(host: side_corporate_host),
      side_staff: OpenStruct.new(host: side_staff_host),
    }
  end
end
