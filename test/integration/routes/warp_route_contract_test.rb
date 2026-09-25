# typed: false
# frozen_string_literal: true

require "test_helper"
require "ostruct"

class WarpRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "Warp app public FQDN keeps its root and dashboard paths" do
    with_boot_config(warp_service_host: "www-jp.umaxica.app") do
      recognized = Rails.application.routes.recognize_path("https://www-jp.umaxica.app/", method: :get)

      assert_equal "warp/app/roots", recognized[:controller]
      assert_equal "index", recognized[:action]

      recognized = Rails.application.routes.recognize_path(
        "https://www-jp.umaxica.app/dashboard",
        method: :get,
      )

      assert_equal "warp/app/dashboards", recognized[:controller]
      assert_equal "show", recognized[:action]
    end
  ensure
    Rails.application.reload_routes!
  end

  test "Warp com and org public FQDNs keep their root paths" do
    with_boot_config(
      warp_corporate_host: "www-jp.umaxica.com",
      warp_staff_host: "www-jp.umaxica.org",
    ) do
      {
        "https://www-jp.umaxica.com/" => "warp/com/roots",
        "https://www-jp.umaxica.org/" => "warp/org/roots",
      }.each do |url, expected_controller|
        recognized = Rails.application.routes.recognize_path(url, method: :get)

        assert_equal expected_controller, recognized[:controller], url
        assert_equal "index", recognized[:action], url
      end
    end
  ensure
    Rails.application.reload_routes!
  end

  test "Warp keeps public theme and cookie endpoint paths for every surface" do
    with_boot_config(
      warp_service_host: "www-jp.umaxica.app",
      warp_corporate_host: "www-jp.umaxica.com",
      warp_staff_host: "www-jp.umaxica.org",
    ) do
      {
        "https://www-jp.umaxica.app/web/v0/theme" => "warp/app/web/v0/themes",
        "https://www-jp.umaxica.app/web/v0/cookie" => "warp/app/web/v0/cookies",
        "https://www-jp.umaxica.com/web/v0/theme" => "warp/com/web/v0/themes",
        "https://www-jp.umaxica.com/web/v0/cookie" => "warp/com/web/v0/cookies",
        "https://www-jp.umaxica.org/web/v0/theme" => "warp/org/web/v0/themes",
        "https://www-jp.umaxica.org/web/v0/cookie" => "warp/org/web/v0/cookies",
      }.each do |url, controller|
        recognized = Rails.application.routes.recognize_path(url, method: :patch)

        assert_equal controller, recognized[:controller], url
        assert_equal "update", recognized[:action], url
      end
    end
  ensure
    Rails.application.reload_routes!
  end

  test "Warp neutral sign entry and callback keep their public paths" do
    with_boot_config(
      warp_service_host: "www-jp.umaxica.app",
      warp_corporate_host: "www-jp.umaxica.com",
      warp_staff_host: "www-jp.umaxica.org",
    ) do
      {
        "https://www-jp.umaxica.app" => "warp/app",
        "https://www-jp.umaxica.com" => "warp/com",
        "https://www-jp.umaxica.org" => "warp/org",
      }.each do |origin, prefix|
        recognized = Rails.application.routes.recognize_path("#{origin}/sign", method: :get)

        assert_equal "#{prefix}/sign/entries", recognized[:controller], origin
        recognized = Rails.application.routes.recognize_path("#{origin}/sign/callback", method: :get)

        assert_equal "#{prefix}/oidc/callbacks", recognized[:controller], origin
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("#{origin}/sign/in", method: :get)
        end
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("#{origin}/sign/in/callback", method: :get)
        end
        ["/oidc/authorization", "/oidc/callback"].each do |path|
          assert_raises(ActionController::RoutingError) do
            Rails.application.routes.recognize_path("#{origin}#{path}", method: :get)
          end
        end
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

  def with_boot_config(warp_service_host: "www-jp.umaxica.app",
                       warp_corporate_host: "www-jp.umaxica.com",
                       warp_staff_host: "www-jp.umaxica.org")
    hosts = warp_route_boot_hosts(warp_service_host, warp_corporate_host, warp_staff_host)

    Rails.configuration.x.stub(:boot_config, BootConfig.new(hosts)) do
      Rails.application.reload_routes!
      yield
    ensure
      Rails.application.reload_routes!
    end
  end

  def warp_route_boot_hosts(warp_service_host, warp_corporate_host, warp_staff_host)
    hosts = Rails.configuration.x.boot_config.fetch(:hosts).to_h
    hosts[:auth_service] = hosts.fetch(:sign_service)
    hosts[:auth_corporate] = hosts.fetch(:sign_corporate)
    hosts[:auth_staff] = hosts.fetch(:sign_staff)
    hosts[:warp_service] = OpenStruct.new(host: warp_service_host)
    hosts[:warp_corporate] = OpenStruct.new(host: warp_corporate_host)
    hosts[:warp_staff] = OpenStruct.new(host: warp_staff_host)
    OpenStruct.new(**hosts)
  end
end
