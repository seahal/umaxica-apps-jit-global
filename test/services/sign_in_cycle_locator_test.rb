# typed: false
# frozen_string_literal: true

require "test_helper"

# The locator reads the sign-in cycle out of a browser session it does not own.
# A payload that has lost a key is a corrupted session, not a crash: the caller
# must see "no cycle" and start over.
class SignInCycleLocatorTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a session payload missing the public id resolves to no cycle instead of raising" do
    session = { app_sign_in_flow_locator: { "nonce" => SecureRandom.hex(8) } }

    assert_nil SignInCycleLocator.new(session, surface: :app).current
  end

  test "a session with no locator entry at all resolves to no cycle" do
    assert_nil SignInCycleLocator.new({}, surface: :app).current
  end

  test "stored reports whether this surface's locator entry exists, whatever its contents" do
    assert_not SignInCycleLocator.new({}, surface: :app).stored?
    assert_not SignInCycleLocator.new({ org_sign_in_flow_locator: {} }, surface: :app).stored?
    assert_predicate SignInCycleLocator.new({ app_sign_in_flow_locator: {} }, surface: :app), :stored?
  end
end
