# typed: false
# frozen_string_literal: true

require "test_helper"

# D-60 (WU-01): the Local Sign-in Flow receiver (Base `/sign/completion`) and its Auth handoff
# (`/sign/handoff`) are removed on every surface.
class RetiredLocalSignInRouteTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  BOOT_HOSTS = Rails.configuration.x.boot_config.fetch(:hosts)

  test "Base local completion is not routable on any Base surface" do
    [BOOT_HOSTS.base_service.host, BOOT_HOSTS.base_corporate.host, BOOT_HOSTS.base_staff.host].each do |host|
      %i(get post).each do |method|
        assert_raises(ActionController::RoutingError, "#{method} #{host}") do
          Rails.application.routes.recognize_path("http://#{host}/sign/completion", method: method)
        end
      end
    end
  end

  test "Auth local handoff is not routable on any Auth surface" do
    [ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
     ENV.fetch("PUBLIC_AUTH_STAFF_URL"),].each do |host|
      %i(get post).each do |method|
        assert_raises(ActionController::RoutingError, "#{method} #{host}") do
          Rails.application.routes.recognize_path("http://#{host}/sign/handoff", method: method)
        end
      end
    end
  end
end
