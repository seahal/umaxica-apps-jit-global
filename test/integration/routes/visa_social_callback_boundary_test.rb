# frozen_string_literal: true

require "test_helper"

class VisaSocialCallbackBoundaryTest < ActionDispatch::IntegrationTest
  test "A02-15: Visa surfaces do not route provider callbacks" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    [hosts.visa_service.host, hosts.visa_corporate.host, hosts.visa_staff.host].each do |host|
      %w(google apple entra).each do |provider|
        %i(get post).each do |method|
          assert_raises(ActionController::RoutingError, "#{host} #{provider} #{method}") do
            Rails.application.routes.recognize_path("https://#{host}/social/#{provider}/callback", method: method)
          end
        end
      end
    end
  end
end
