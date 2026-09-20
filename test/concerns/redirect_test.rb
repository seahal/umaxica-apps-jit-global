# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class RedirectTest < ActiveSupport::TestCase
  include CommonRedirect

  setup do
    @original_env = ENV.to_h
    ENV["CORPORATE_URL"] = "https://com.localhost"
    ENV["SERVICE_URL"] = "https://app.localhost"
    ENV["STAFF_URL"] = "https://org.localhost"
    ENV["NETWORK_URL"] = "https://net.localhost"
    ENV["DEV_URL"] = "https://dev.localhost"
  end

  teardown do
    ENV.clear
    ENV.update(@original_env)
  end

  test "allowed_hosts uses simplified environment keys" do
    hosts = allowed_hosts

    assert_equal %w(com.localhost app.localhost org.localhost net.localhost dev.localhost), hosts
  end
end
