# frozen_string_literal: true

require "test_helper"
require "open3"

class EntraOmniauthBootCredentialsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  TENANT_ID = "11111111-2222-3333-4444-555555555555"
  CLIENT_ID = "22222222-3333-4444-5555-666666666666"
  # Not a real credential.
  CLIENT_SECRET = "test-only-client-secret-value"

  PRODUCTION = ActiveSupport::StringInquirer.new("production")
  STAGING = ActiveSupport::StringInquirer.new("staging")
  DEVELOPMENT = ActiveSupport::StringInquirer.new("development")
  TEST = ActiveSupport::StringInquirer.new("test")

  test "returns all three credentials when they are configured" do
    credentials = resolve(env: PRODUCTION)

    assert_equal TENANT_ID, credentials.tenant_id
    assert_equal CLIENT_ID, credentials.client_id
    assert_equal CLIENT_SECRET, credentials.client_secret
  end

  test "each of the three credentials is required in a non-local environment" do
    {
      "OMNI_AUTH_ENTRA_ORG_TENANT_ID" => { tenant_id: "" },
      "OMNI_AUTH_ENTRA_ORG_CLIENT_ID" => { client_id: "" },
      "OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET" => { client_secret: nil },
    }.each do |key, override|
      error = assert_raises(KeyError) { resolve(env: PRODUCTION, **override) }

      assert_equal "#{key} is required for Microsoft Entra ID authentication", error.message
    end
  end

  test "staging fails closed the same way production does" do
    error = assert_raises(KeyError) { resolve(env: STAGING, tenant_id: nil, client_id: nil, client_secret: nil) }

    assert_includes error.message, "OMNI_AUTH_ENTRA_ORG_TENANT_ID"
  end

  test "the tenant id and client id must be UUIDs" do
    tenant_error = assert_raises(KeyError) { resolve(env: PRODUCTION, tenant_id: "contoso.onmicrosoft.com") }

    assert_equal "OMNI_AUTH_ENTRA_ORG_TENANT_ID must be a valid UUID", tenant_error.message

    client_error = assert_raises(KeyError) { resolve(env: PRODUCTION, client_id: "not-a-uuid") }

    assert_equal "OMNI_AUTH_ENTRA_ORG_CLIENT_ID must be a valid UUID", client_error.message
  end

  test "common, organizations and consumers are rejected as tenant ids by the UUID rule" do
    %w(common organizations consumers).each do |pseudo_tenant|
      error = assert_raises(KeyError) { resolve(env: PRODUCTION, tenant_id: pseudo_tenant) }

      assert_equal "OMNI_AUTH_ENTRA_ORG_TENANT_ID must be a valid UUID", error.message
    end
  end

  test "no credential value ever appears in an error message" do
    [
      { tenant_id: "leaked-tenant-value" },
      { client_id: "leaked-client-value" },
      { tenant_id: "", client_id: "", client_secret: "leaked-secret-value" },
    ].each do |override|
      error = assert_raises(KeyError) { resolve(env: PRODUCTION, **override) }

      override.each_value do |value|
        next if value.blank?

        assert_not_includes error.message, value
      end
      assert_not_includes error.message, CLIENT_SECRET
      assert_not_includes error.message, TENANT_ID
      assert_not_includes error.message, CLIENT_ID
    end
  end

  test "development and test boot without any Entra credentials and omit the provider" do
    [DEVELOPMENT, TEST].each do |env|
      assert_nil resolve(env: env, tenant_id: nil, client_id: nil, client_secret: nil)
      assert_nil resolve(env: env, tenant_id: "", client_id: "", client_secret: "")
    end
  end

  test "a partially configured local environment still fails instead of silently disabling Entra" do
    error = assert_raises(KeyError) { resolve(env: DEVELOPMENT, client_secret: "") }

    assert_equal "OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET is required for Microsoft Entra ID authentication", error.message
  end

  test "a fully configured local environment returns the credentials" do
    assert_equal TENANT_ID, resolve(env: TEST).tenant_id
  end

  test "boot validation makes no network call" do
    # Any outbound HTTP during boot validation would make Rails boot depend on
    # Microsoft being reachable. Semantic checks stay in OrgEntraSignInPreflight.
    Net::HTTP.stub(:start, ->(*, **) { flunk("boot validation must not perform network I/O") }) do
      assert_equal CLIENT_ID, resolve(env: PRODUCTION).client_id
    end
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
        result = EntraOmniauthBootCredentials.resolve_for_boot(
          tenant_id: nil, client_id: nil, client_secret: nil, env: env,
        )
        abort "expected nil without entra credentials" unless result.nil?
        puts "publishing_boot_without_entra_secret=ok"
      RUBY
    )

    assert_predicate status, :success?, "stderr=#{stderr} stdout=#{stdout}"
    assert_includes stdout, "publishing_boot_without_entra_secret=ok"
  end

  private

  def resolve(env:, tenant_id: TENANT_ID, client_id: CLIENT_ID, client_secret: CLIENT_SECRET)
    EntraOmniauthBootCredentials.resolve_for_boot(
      tenant_id: tenant_id, client_id: client_id, client_secret: client_secret, env: env,
    )
  end
end
