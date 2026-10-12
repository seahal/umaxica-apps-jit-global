# frozen_string_literal: true

require "test_helper"

class PublicIdGenerationTest < ActiveSupport::TestCase
  test "standard generation returns one URL-safe 21-character opaque string" do
    identifier = PublicId.generate

    assert_kind_of String, identifier
    assert_equal 21, identifier.length
    assert_match(/\A[A-Za-z0-9_-]{21}\z/, identifier)
  end

  test "standard generation does not expose caller-selected size alphabet or nonsecure mode" do
    [{ size: nil }, { size: 0 }, { size: 20 }, { size: 21 }, { size: 22 },
     { alphabet: "abc" }, { non_secure: true },].each do |options|
      assert_raises(ArgumentError) { PublicId.generate(**options) }
    end
  end
end
