# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class PrimaryAuthenticationAccountRateLimitInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      RETIRED_CONTROLLERS = %w(
        app/controllers/auth/com/sign/in/secrets_controller.rb
        app/controllers/auth/org/sign/in/secrets_controller.rb
      ).freeze

      test "com and org permanent secret sign-in controllers are removed" do
        offenders = RETIRED_CONTROLLERS.select { |path| Rails.root.join(path).exist? }

        assert_empty offenders
      end

      test "app publishes its admitted secret credential ceremony" do
        host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        { get: ["/sign/in/secret/new", "new"], post: ["/sign/in/secret", "create"] }.each do |method, (path, action)|
          route = Rails.application.routes.recognize_path("https://#{host}#{path}", method: method)

          assert_equal "auth/app/sign/in/secrets", route.fetch(:controller)
          assert_equal action, route.fetch(:action)
        end
      end

      test "com and org permanent secret sign-in paths are absent" do
        hosts = Rails.configuration.x.boot_config.fetch(:hosts)
        sign_hosts = [hosts.sign_corporate.host, hosts.sign_staff.host]

        sign_hosts.each do |host|
          %i(get post).each do |method|
            assert_raises(ActionController::RoutingError) do
              Rails.application.routes.recognize_path("http://#{host}/sign/in/secret", method: method)
            end
          end
        end
      end
    end
  end
end
