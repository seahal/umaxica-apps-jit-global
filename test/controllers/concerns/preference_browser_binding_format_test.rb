# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceBrowserBindingFormatTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "binding values use the canonical unpadded encoding of exactly 32 bytes" do
    value = PreferenceBrowserBinding.mint_value
    digest = PreferenceBrowserBinding.digest_for(value)

    assert PreferenceBrowserBinding.valid_value?(value)
    assert PreferenceBrowserBinding.matches?(value, digest)
    assert_not PreferenceBrowserBinding.valid_value?(value[0, 42])
    assert_not PreferenceBrowserBinding.valid_value?(value + "A")
    assert_not PreferenceBrowserBinding.valid_value?(("A" * 42) + "B")
    assert_not PreferenceBrowserBinding.matches?(("A" * 42) + "B", digest)
    assert_not PreferenceBrowserBinding.valid_value?(nil)
    assert_not PreferenceBrowserBinding.valid_value?(123)
  end
end
