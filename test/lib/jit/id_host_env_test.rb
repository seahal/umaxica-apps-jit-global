# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_id_host_env"

module Jit
  class IdHostEnvTest < ActiveSupport::TestCase
    def setup
      @original_env = {
        "PRIVATE_AUTH_SERVICE_URL" => ENV["PRIVATE_AUTH_SERVICE_URL"],
        "PRIVATE_AUTH_STAFF_URL" => ENV["PRIVATE_AUTH_STAFF_URL"],
      }
    end

    def teardown
      return unless @original_env

      @original_env.each do |key, value|
        ENV[key] = value
      end
    end

    test "service_url returns PRIVATE_AUTH_SERVICE_URL" do
      ENV["PRIVATE_AUTH_SERVICE_URL"] = "http://id.app.localhost"

      assert_equal "http://id.app.localhost", JitIdHostEnv.service_url
    end

    test "staff_url returns PRIVATE_AUTH_STAFF_URL" do
      ENV["PRIVATE_AUTH_STAFF_URL"] = "http://id.org.localhost"

      assert_equal "http://id.org.localhost", JitIdHostEnv.staff_url
    end

    test "validate! raises error when env is missing" do
      ENV["PRIVATE_AUTH_SERVICE_URL"] = nil
      ENV["PRIVATE_AUTH_STAFF_URL"] = "present"

      error =
        assert_raises(JitIdHostEnv::MissingHostError) do
          JitIdHostEnv.validate!
        end
      assert_match(/Missing required id host env: PRIVATE_AUTH_SERVICE_URL/, error.message)
    end

    test "validate! does not raise error when all env are present" do
      ENV["PRIVATE_AUTH_SERVICE_URL"] = "present"
      ENV["PRIVATE_AUTH_STAFF_URL"] = "present"

      assert_nothing_raised do
        JitIdHostEnv.validate!
      end
    end
  end
end
