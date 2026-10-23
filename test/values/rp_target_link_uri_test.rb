# typed: false
# frozen_string_literal: true

require "test_helper"

# D-151 / A43-13: only a relative path on the RP's own host becomes a target.
class RpTargetLinkUriTest < ActiveSupport::TestCase
  test "relative paths are kept" do
    assert_equal "/dashboard", RpTargetLinkUri.normalize("/dashboard")
    assert_equal "/a/b-c_d.e", RpTargetLinkUri.normalize("/a/b-c_d.e")
  end

  test "queries, fragments, other hosts, dot segments, encoding and reserved prefixes are ignored" do
    [
      nil, "", "dashboard", "/dashboard?x=1", "/dashboard#top", "//evil.example/x", "https://evil.example/x",
      "/a/../b", "/./a", "/a%2fb", "/a%252fb", "/sign", "/sign/in", "/oidc", "/oidc/callback", "/a b",
      "/a\\b", "/a\u0000",
    ].each { |value| assert_nil RpTargetLinkUri.normalize(value), value.inspect }
  end
end
