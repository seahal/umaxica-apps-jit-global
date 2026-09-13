# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require Rails.root.join("lib/config_values_origin_value").to_s

class ConfigValuesOriginValueTest < ActiveSupport::TestCase
  test "rejects query userinfo and bad scheme" do
    assert_raises(ArgumentError) { ConfigValues.build("ftp://example.com") }
    assert_raises(ArgumentError) { ConfigValues.build("https://user@example.com") }
    assert_raises(ArgumentError) { ConfigValues.build("https://example.com?x=1") }
  end

  test "allows localhost http only in local mode" do
    assert_nothing_raised { ConfigValues.build("http://localhost:3000", allow_localhost: true) }
    assert_raises(ArgumentError) { ConfigValues.build("http://example.com", allow_localhost: true) }
  end

  test "rejects fragment and non-root paths" do
    assert_raises(ArgumentError) { ConfigValues.build("https://example.com#frag") }
    assert_raises(ArgumentError) { ConfigValues.build("https://example.com/path") }
  end

  test "rejects unparseable URI with invalid origin" do
    assert_raises(ArgumentError) { ConfigValues.build("https://[invalid-bracket") }
    assert_raises(ArgumentError) { ConfigValues.build("https://example.com:port") }
  end

  test "normalizes trailing path and downcases host" do
    value = ConfigValues.build("https://EXAMPLE.com/", allow_localhost: false)

    assert_equal "https://example.com", value.to_s
    assert_equal "example.com", value.host
  end

  test "accepts bare host origins by treating them as https" do
    value = ConfigValues.build("jump.umaxica.net")

    assert_equal "https://jump.umaxica.net", value.to_s
    assert_equal "jump.umaxica.net", value.host
  end

  test "rejects blank and control-character origins" do
    assert_raises(ArgumentError) { ConfigValues.build("") }
    assert_raises(ArgumentError) { ConfigValues.build("https://example.com" + 1.chr) }
  end
end
