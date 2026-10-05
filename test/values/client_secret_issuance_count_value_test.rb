# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientSecretIssuanceCountValueTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "passkey registration adds two for every count from zero through eighteen" do
    (0..18).each do |active_count|
      value = ClientSecretIssuanceCountValue.new(active_count: active_count, reserved_count: 0)

      assert_equal 2, value.passkey_count, "active count #{active_count}"
      assert_equal 1, value.manual_count, "active count #{active_count}"
    end
  end

  test "eighteen nineteen and twenty partition passkey distribution at capacity" do
    [[18, 2], [19, 1], [20, 0]].each do |active_count, expected_count|
      value = ClientSecretIssuanceCountValue.new(active_count: active_count, reserved_count: 0)

      assert_equal expected_count, value.passkey_count
    end
  end

  test "manual issuance at nineteen adds one and at twenty omits issuance" do
    assert_equal 1, ClientSecretIssuanceCountValue.new(active_count: 19, reserved_count: 0).manual_count
    assert_equal 0, ClientSecretIssuanceCountValue.new(active_count: 20, reserved_count: 0).manual_count
  end

  test "one valid credential receives two additional credentials rather than top up to two" do
    value = ClientSecretIssuanceCountValue.new(active_count: 1, reserved_count: 0)

    assert_equal 3, 1 + value.passkey_count
  end

  test "another live reservation is a conflict rather than twenty valid credentials" do
    [[18, 2], [19, 1], [0, 1]].each do |active_count, reserved_count|
      value = ClientSecretIssuanceCountValue.new(active_count: active_count, reserved_count: reserved_count)

      assert_raises(ClientSecretIssuanceCountValue::ReservationConflict) { value.passkey_count }
      assert_raises(ClientSecretIssuanceCountValue::ReservationConflict) { value.manual_count }
    end
  end

  test "active count rejects below zero and above twenty without coercion" do
    [-1, 21, nil, "", "0", 0.0, [], {}, false].each do |active_count|
      assert_raises(ArgumentError) do
        ClientSecretIssuanceCountValue.new(active_count: active_count, reserved_count: 0)
      end
    end
  end

  test "reservation count rejects invalid types negative counts and capacity overflow" do
    [-1, 21, nil, "", "0", 0.0, [], {}, false].each do |reserved_count|
      assert_raises(ArgumentError) do
        ClientSecretIssuanceCountValue.new(active_count: 0, reserved_count: reserved_count)
      end
    end

    assert_raises(ArgumentError) do
      ClientSecretIssuanceCountValue.new(active_count: 19, reserved_count: 2)
    end
  end
end
