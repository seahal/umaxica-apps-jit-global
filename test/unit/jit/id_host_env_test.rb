# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_id_host_env"

module Jit
  class IdHostEnvTest < ActiveSupport::TestCase
    test "service_url reads PRIVATE_AUTH_SERVICE_URL" do
      with_env("PRIVATE_AUTH_SERVICE_URL" => "id.app.example.test") do
        assert_equal "id.app.example.test", ENV["PRIVATE_AUTH_SERVICE_URL"]
        assert_equal "id.app.example.test", JitIdHostEnv.service_url
      end
    end

    test "service_url returns nil when blank" do
      with_env("PRIVATE_AUTH_SERVICE_URL" => "") do
        assert_nil JitIdHostEnv.service_url
      end
    end

    test "staff_url reads PRIVATE_AUTH_STAFF_URL" do
      with_env("PRIVATE_AUTH_STAFF_URL" => "id.org.example.test") do
        assert_equal "id.org.example.test", JitIdHostEnv.staff_url
      end
    end

    test "validate! raises when service host is missing" do
      with_env(
        "PRIVATE_AUTH_SERVICE_URL" => nil, "PRIVATE_AUTH_STAFF_URL" => "id.org.example.test",
      ) do
        error = assert_raises(JitIdHostEnv::MissingHostError) { JitIdHostEnv.validate! }

        assert_includes error.message, "PRIVATE_AUTH_SERVICE_URL"
      end
    end

    test "validate! raises when staff host is missing" do
      with_env(
        "PRIVATE_AUTH_SERVICE_URL" => "id.app.example.test", "PRIVATE_AUTH_STAFF_URL" => nil,
      ) do
        error = assert_raises(JitIdHostEnv::MissingHostError) { JitIdHostEnv.validate! }

        assert_includes error.message, "PRIVATE_AUTH_STAFF_URL"
      end
    end

    test "validate! passes when all hosts are present" do
      with_env(
        "PRIVATE_AUTH_SERVICE_URL" => "id.app.example.test", "PRIVATE_AUTH_STAFF_URL" => "id.org.example.test",
      ) do
        assert_nil JitIdHostEnv.validate!
      end
    end

    test "validate! reports every missing host" do
      with_env(
        "PRIVATE_AUTH_SERVICE_URL" => nil,
        "PRIVATE_AUTH_STAFF_URL" => nil,
      ) do
        error = assert_raises(JitIdHostEnv::MissingHostError) { JitIdHostEnv.validate! }

        assert_includes error.message, "PRIVATE_AUTH_SERVICE_URL"
        assert_includes error.message, "PRIVATE_AUTH_STAFF_URL"
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
