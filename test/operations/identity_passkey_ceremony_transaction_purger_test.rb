# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityPasskeyCeremonyTransactionPurgerTest < ActiveSupport::TestCase
  test "call returns a hash with app and org keys" do
    result = IdentityPasskeyCeremonyTransactionPurger.call

    assert_kind_of Hash, result
    assert_equal %w(app org), result.keys.sort
  end

  test "call accepts custom now and retention_period" do
    result = IdentityPasskeyCeremonyTransactionPurger.call(now: Time.current, retention_period: 1.day)

    assert_kind_of Hash, result
    assert_equal %w(app org), result.keys.sort
  end
end
