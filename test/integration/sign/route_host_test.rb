# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "ostruct"

class SignRouteHostTest < ActionDispatch::IntegrationTest
  test "sign app routes match PRIVATE_AUTH_SERVICE_URL" do
    with_boot_config(sign_service_host: "auth.app.example.test") do
      host!("auth.app.example.test")

      route = Rails.application.routes.recognize_path("http://auth.app.example.test/", method: :get)

      assert_equal "auth/app/roots", route[:controller]
      assert_equal "index", route[:action]
    end
  ensure
    Rails.application.reload_routes!
  end

  test "sign com named root route points at sign/com/roots#index" do
    with_boot_config(sign_corporate_host: "auth.com.example.test") do
      route = Rails.application.routes.named_routes[:auth_com_root]

      assert_equal "/", route.path.spec.to_s
      assert_equal "auth/com/roots", route.defaults[:controller]
      assert_equal "index", route.defaults[:action]
    end
  ensure
    Rails.application.reload_routes!
  end

  test "sign org routes match AUTH_STAFF_URL" do
    with_boot_config(sign_staff_host: "auth.org.example.test") do
      host!("auth.org.example.test")

      route = Rails.application.routes.recognize_path("http://auth.org.example.test/", method: :get)

      assert_equal "auth/org/roots", route[:controller]
      assert_equal "index", route[:action]
    end
  ensure
    Rails.application.reload_routes!
  end

  test "sign routes accept internal origin and cloudflared public hosts" do
    with_boot_config(
      sign_service_host: "auth.umaxica.app",
      sign_corporate_host: "auth.umaxica.com",
      sign_staff_host: "auth.umaxica.org",
    ) do
      {
        "auth.app.localhost" => "auth/app/roots",
        "auth.com.localhost" => "auth/com/roots",
        "auth.org.localhost" => "auth/org/roots",
        "auth.umaxica.app" => "auth/app/roots",
        "auth.umaxica.com" => "auth/com/roots",
        "auth.umaxica.org" => "auth/org/roots",
      }.each do |host, controller|
        route = Rails.application.routes.recognize_path("http://#{host}/", method: :get)

        assert_equal controller, route[:controller]
        assert_equal "index", route[:action]
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

  def with_boot_config(sign_service_host: ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost"),
                       sign_corporate_host: ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost"),
                       sign_staff_host: ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost"))
    hosts = sign_route_boot_hosts(sign_service_host, sign_corporate_host, sign_staff_host)

    Rails.configuration.x.stub(:boot_config, BootConfig.new(hosts)) do
      Rails.application.reload_routes!
      yield
    end
  ensure
    Rails.application.reload_routes!
  end

  def sign_route_boot_hosts(sign_service_host, sign_corporate_host, sign_staff_host)
    OpenStruct.new(
      **sign_route_identity_hosts(sign_service_host, sign_corporate_host, sign_staff_host),
      **sign_route_product_hosts,
    )
  end

  def sign_route_identity_hosts(sign_service_host, sign_corporate_host, sign_staff_host)
    {
      auth_service: OpenStruct.new(host: sign_service_host),
      auth_corporate: OpenStruct.new(host: sign_corporate_host),
      auth_staff: OpenStruct.new(host: sign_staff_host),
      acme_service: OpenStruct.new(host: ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost")),
      acme_corporate: OpenStruct.new(host: ENV.fetch("PRIVATE_BASE_CORPORATE_URL", "www.com.localhost")),
      acme_staff: OpenStruct.new(host: ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost")),
      sign_service: OpenStruct.new(host: ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")),
      sign_corporate: OpenStruct.new(host: ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost")),
      sign_staff: OpenStruct.new(host: ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost")),
    }
  end

  def sign_route_product_hosts
    {
      side_service: OpenStruct.new(host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "wide.app.localhost")),
      side_corporate: OpenStruct.new(host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "wide.com.localhost")),
      side_staff: OpenStruct.new(host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "wide.org.localhost")),
      core_service: OpenStruct.new(host: ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost")),
      core_corporate: OpenStruct.new(host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost")),
      core_staff: OpenStruct.new(host: ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost")),
      base_service: OpenStruct.new(host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")),
      base_corporate: OpenStruct.new(host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")),
      base_staff: OpenStruct.new(host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")),
      palm_service: OpenStruct.new(host: ENV.fetch("PUBLIC_PALM_SERVICE_URL", "palm.app.localhost")),
      palm_corporate: OpenStruct.new(host: Rails.configuration.x.boot_config.fetch(:hosts).palm_corporate.host),
      palm_staff: OpenStruct.new(host: Rails.configuration.x.boot_config.fetch(:hosts).palm_staff.host),
      help_service: OpenStruct.new(host: ENV.fetch("PRIVATE_HELP_SERVICE_URL", "help.app.localhost")),
      help_corporate: OpenStruct.new(host: ENV.fetch("PRIVATE_HELP_CORPORATE_URL", "help.com.localhost")),
      help_staff: OpenStruct.new(host: ENV.fetch("PRIVATE_HELP_STAFF_URL", "help.org.localhost")),
      info_service: OpenStruct.new(host: ENV.fetch("PRIVATE_INFO_SERVICE_URL", "info.app.localhost")),
      info_corporate: OpenStruct.new(host: ENV.fetch("PRIVATE_INFO_CORPORATE_URL", "info.com.localhost")),
      info_staff: OpenStruct.new(host: ENV.fetch("PRIVATE_INFO_STAFF_URL", "info.org.localhost")),
    }
  end
end
