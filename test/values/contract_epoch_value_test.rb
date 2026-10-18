# typed: false
# frozen_string_literal: true

require "test_helper"

class ContractEpochValueTest < ActiveSupport::TestCase
  test "coerces a positive integer and accepts its string form" do
    assert_equal 1, ContractEpochValue.coerce(1)
    assert_equal 7, ContractEpochValue.coerce("7")
    assert ContractEpochValue.valid?(2)
  end

  test "rejects zero negative noninteger and blank values" do
    [0, -1, "", "1.5", nil].each do |value|
      assert_raises(ContractEpochValue::Invalid) { ContractEpochValue.coerce(value) }
      assert_not ContractEpochValue.valid?(value)
    end
  end
end
