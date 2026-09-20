# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class TelephoneRegistrableTest < ActiveSupport::TestCase
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  class MockRequest
    attr_accessor :remote_ip

    def initialize(ip = "192.168.1.1")
      @remote_ip = ip
    end
  end

  class TestController
    include SignTelephoneRegistrable

    attr_accessor :request

    def initialize(ip = "192.168.1.1")
      @request = MockRequest.new(ip)
    end
  end

  setup do
    @controller = TestController.new
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  teardown do
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  # ---------------------------------------------------------------------------
  # check_telephone_verification_rate_limit!
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # initiate_telephone_verification
  # ---------------------------------------------------------------------------

  test "initiate_telephone_verification returns false when user is blank" do
    result = @controller.initiate_telephone_verification(nil, "+819012345678")

    assert_not result
  end

  test "initiate_telephone_verification returns false when user is empty string" do
    result = @controller.initiate_telephone_verification("", "+819012345678")

    assert_not result
  end

  # ---------------------------------------------------------------------------
  # complete_telephone_verification
  # ---------------------------------------------------------------------------

  test "complete_telephone_verification returns :session_expired when record not found" do
    result = @controller.complete_telephone_verification("nonexistent-id", "123456")

    assert_equal :session_expired, result
  end
end
