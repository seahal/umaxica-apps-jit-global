# frozen_string_literal: true

require "test_helper"
require "open3"

class EntraOmniauthBootCredentialsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "returns the configured secret when present" do
    secret = EntraOmniauthBootCredentials.secret_for_boot("configured-secret")

    assert_equal "configured-secret", secret
  end

  test "development and test environments boot without an Entra client secret" do
    assert_nil EntraOmniauthBootCredentials.secret_for_boot("", env: ActiveSupport::StringInquirer.new("test"))
    assert_nil EntraOmniauthBootCredentials.secret_for_boot(nil, env: ActiveSupport::StringInquirer.new("development"))
  end

  test "non-local environments still require the Entra client secret" do
    error =
      assert_raises(KeyError) do
        EntraOmniauthBootCredentials.secret_for_boot("", env: ActiveSupport::StringInquirer.new("production"))
      end

    assert_includes error.message, "OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET"
  end

  test "publishing tests can resolve boot credentials without an Entra IdP secret" do
    env = {
      "BUNDLE_GEMFILE" => ENV.fetch("BUNDLE_GEMFILE"),
      "HOME" => ENV.fetch("HOME"),
      "PATH" => ENV.fetch("PATH"),
      "RAILS_ENV" => "test",
    }
    stdout, stderr, status = Open3.capture3(
      env,
      Gem.ruby,
      "-e",
      <<~RUBY,
        require "bundler/setup"
        require "rails"
        require "active_support/string_inquirer"
        require #{Rails.root.join("lib/entra_omniauth_boot_credentials").to_s.inspect}
        env = ActiveSupport::StringInquirer.new("test")
        result = EntraOmniauthBootCredentials.secret_for_boot(nil, env: env)
        abort "expected nil without entra secret" unless result.nil?
        puts "publishing_boot_without_entra_secret=ok"
      RUBY
    )

    assert_predicate status, :success?, "stderr=#{stderr} stdout=#{stdout}"
    assert_includes stdout, "publishing_boot_without_entra_secret=ok"
  end
end
