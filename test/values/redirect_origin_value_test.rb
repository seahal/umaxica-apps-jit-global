# frozen_string_literal: true

require "test_helper"

class RedirectOriginValueTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "same origin compares scheme hostname and effective port" do
    origin = "https://Example.test:443"

    assert RedirectOriginValue.same_origin?(target: "https://example.test/path?q=1", origin:)
    assert RedirectOriginValue.same_origin?(target: "https://EXAMPLE.test:443/", origin:)
    assert_not RedirectOriginValue.same_origin?(target: "https://example.test:442/", origin:)
    assert_not RedirectOriginValue.same_origin?(target: "https://example.test:444/", origin:)
    assert_not RedirectOriginValue.same_origin?(target: "http://example.test/", origin:)
    assert_not RedirectOriginValue.same_origin?(target: "https://other.test/", origin:)
  end

  test "malformed relative and credential-bearing URLs are not same-origin" do
    origin = "https://example.test"

    [nil, "", "/path", "//example.test/path", "https://[invalid", "https://user@example.test/"].each do |target|
      assert_not RedirectOriginValue.same_origin?(target:, origin:)
    end
    assert_not RedirectOriginValue.same_origin?(target: "https://example.test/", origin: nil)
  end
end
