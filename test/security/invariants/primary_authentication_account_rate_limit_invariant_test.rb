# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class PrimaryAuthenticationAccountRateLimitInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      RETIRED_CONTROLLERS = %w(
        app/controllers/auth/app/sign/in/secrets_controller.rb
        app/controllers/auth/com/sign/in/secrets_controller.rb
        app/controllers/auth/org/sign/in/secrets_controller.rb
      ).freeze

      test "legacy secret sign-in controllers are removed" do
        offenders = RETIRED_CONTROLLERS.select { |path| Rails.root.join(path).exist? }

        assert_empty offenders
      end

      test "legacy secret sign-in path is absent from every Auth surface" do
        hosts = Rails.configuration.x.boot_config.fetch(:hosts)
        sign_hosts = [hosts.sign_service.host, hosts.sign_corporate.host, hosts.sign_staff.host]

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
