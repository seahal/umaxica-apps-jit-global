# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class PrimaryAuthenticationAccountRateLimitInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      CONTROLLERS = {
        "app/controllers/auth/app/sign/in/secrets_controller.rb" => ["app", "secret_credential_create_identifier"],
        "app/controllers/auth/com/sign/in/secrets_controller.rb" => ["com", "secret_credential_create_identifier"],
        "app/controllers/auth/org/sign/in/secrets_controller.rb" => ["org", "secret_credential_create_actor"],
      }.freeze

      test "every secret credential entry point limits attempts by a private identifier digest" do
        CONTROLLERS.each do |relative_path, (surface, rule_name)|
          source = Rails.root.join(relative_path).read

          assert_includes source, "name: \"#{rule_name}\""
          assert_includes source, "AuthenticationRateLimitKey.for("
          assert_includes source, "surface: :#{surface}"
        end
      end
    end
  end
end
