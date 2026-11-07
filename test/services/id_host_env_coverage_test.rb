# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdHostEnvCoverageTest < ActiveSupport::TestCase
  test "JitIdHostEnv coverage" do
    with_env(
      "PRIVATE_AUTH_SERVICE_URL" => "id.app.example.test",
      "PRIVATE_AUTH_STAFF_URL" => "id.org.example.test",
    ) do
      assert_equal "id.app.example.test", JitIdHostEnv.service_url
      assert_equal "id.org.example.test", JitIdHostEnv.staff_url
      assert_nil JitIdHostEnv.validate!
    end

    with_env("PRIVATE_AUTH_SERVICE_URL" => nil) do
      error = assert_raises(JitIdHostEnv::MissingHostError) { JitIdHostEnv.validate! }
      assert_includes error.message, "PRIVATE_AUTH_SERVICE_URL"
    end
  end

  private

  def with_env(vars)
    original = {}
    vars.each_key { |key| original[key] = ENV[key] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end
end
