# typed: false
# frozen_string_literal: true

require "test_helper"

# D-63: Base no longer serves `/edge/v0/cookie`; cookie consent is `/api/v0/preferences/cookie`.
class BaseRetiredEdgeCookieRouteTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  BOOT_HOSTS = Rails.configuration.x.boot_config.fetch(:hosts)

  test "edge cookie is not routable on any Base surface" do
    [BOOT_HOSTS.base_service.host, BOOT_HOSTS.base_corporate.host, BOOT_HOSTS.base_staff.host].each do |host|
      %i(get patch put).each do |method|
        assert_raises(ActionController::RoutingError, "#{method} #{host}") do
          Rails.application.routes.recognize_path("http://#{host}/edge/v0/cookie", method: method)
        end
      end
    end
  end

  test "the API cookie endpoint stays routable on every Base surface" do
    [BOOT_HOSTS.base_service.host, BOOT_HOSTS.base_corporate.host, BOOT_HOSTS.base_staff.host].each do |host|
      recognized = Rails.application.routes.recognize_path("http://#{host}/api/v0/preferences/cookie", method: :get)

      assert_match %r{\Abase/(app|com|org)/api/v0/preferences/cookies\z}, recognized[:controller]
    end
  end
end
