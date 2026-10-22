# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_session_cookie_config"

module Jit
  class SessionCookieConfigTest < ActiveSupport::TestCase
    # --- cookie_key ---

    test "cookie_key returns __Host-session when force_secure is true" do
      assert_equal "__Host-session", JitSessionCookieConfig.cookie_key(force_secure: true)
    end

    test "cookie_key returns session when force_secure is false" do
      assert_equal "session", JitSessionCookieConfig.cookie_key(force_secure: false)
    end

    # --- force_secure? in production ---

    test "force_secure is true in production" do
      env = ActiveSupport::EnvironmentInquirer.new("production")

      assert JitSessionCookieConfig.force_secure?(id_service_host: "", rails_env: env)
    end

    # --- force_secure? in test ---

    test "force_secure is false in test even with production-like host" do
      env = ActiveSupport::EnvironmentInquirer.new("test")

      assert_not JitSessionCookieConfig.force_secure?(id_service_host: "sign.app.example.com", rails_env: env)
    end

    # --- force_secure? in development ---

    test "force_secure is false in development with localhost" do
      env = ActiveSupport::EnvironmentInquirer.new("development")

      assert_not JitSessionCookieConfig.force_secure?(id_service_host: "id.app.localhost", rails_env: env)
    end

    test "force_secure is false in development even with non-local host" do
      env = ActiveSupport::EnvironmentInquirer.new("development")

      assert_not JitSessionCookieConfig.force_secure?(id_service_host: "sign.app.example.com", rails_env: env)
    end

    test "force_secure is false in development with empty host" do
      env = ActiveSupport::EnvironmentInquirer.new("development")

      assert_not JitSessionCookieConfig.force_secure?(id_service_host: "", rails_env: env)
    end

    # --- FORCE_SECURE_COOKIES env var ---

    test "force_secure is true when FORCE_SECURE_COOKIES=1 in development" do
      env = ActiveSupport::EnvironmentInquirer.new("development")

      with_env("FORCE_SECURE_COOKIES" => "1") do
        assert JitSessionCookieConfig.force_secure?(id_service_host: "", rails_env: env)
      end
    end

    test "force_secure is false when FORCE_SECURE_COOKIES=1 in test" do
      env = ActiveSupport::EnvironmentInquirer.new("test")

      with_env("FORCE_SECURE_COOKIES" => "1") do
        assert_not JitSessionCookieConfig.force_secure?(id_service_host: "", rails_env: env)
      end
    end

    # --- non-local host detection ---

    test "force_secure is false with 127.x host in production-like staging" do
      env = ActiveSupport::EnvironmentInquirer.new("production")

      assert JitSessionCookieConfig.force_secure?(id_service_host: "127.0.0.1", rails_env: env),
             "production always forces secure regardless of host"
    end

    test "force_secure is true outside development and test without env override" do
      env = ActiveSupport::EnvironmentInquirer.new("staging")

      with_env("FORCE_SECURE_COOKIES" => nil) do
        assert JitSessionCookieConfig.force_secure?(id_service_host: "0.0.0.0", rails_env: env)
      end
    end

    test "force_secure is true with non-local host in staging" do
      env = ActiveSupport::EnvironmentInquirer.new("staging")

      with_env("FORCE_SECURE_COOKIES" => nil) do
        assert JitSessionCookieConfig.force_secure?(id_service_host: "sign.app.example.com", rails_env: env)
      end
    end

    private

    def with_env(vars)
      original = {}
      vars.each_key { |key| original[key] = ENV[key] }

      vars.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end

      yield
    ensure
      original.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end
    end
  end
end
