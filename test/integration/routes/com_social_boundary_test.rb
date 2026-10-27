# frozen_string_literal: true

require "test_helper"

class ComSocialBoundaryTest < ActionDispatch::IntegrationTest
  test "A05-13: COM does not route social sign-in or sign-up entry and callback paths" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    %w(google apple entra).each do |provider|
      %W(/social/#{provider}/session /social/#{provider}/registration /social/#{provider}/callback).each do |path|
        %i(get post).each do |method|
          assert_raises(ActionController::RoutingError, "#{provider} #{path} #{method}") do
            Rails.application.routes.recognize_path("https://#{host}#{path}", method: method)
          end
        end
      end
    end
  end
end
