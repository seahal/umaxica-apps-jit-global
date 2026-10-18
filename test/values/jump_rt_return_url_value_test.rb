# frozen_string_literal: true

require "test_helper"

class JumpRtReturnUrlValueTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "keeps query pair order in the canonical url" do
    value = JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?b=2&a=1")

    assert_equal "https://www.umaxica.app/path?b=2&a=1", value.canonical_without_return_token
  end

  test "reordered query pairs produce different canonical urls" do
    first = JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?a=1&b=2")
    second = JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?b=2&a=1")

    assert_not_equal first.canonical_without_return_token, second.canonical_without_return_token
  end

  test "removes exactly the single rt pair and exposes its value" do
    value = JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?ok=1&rt=a.b.c&x=2")

    assert_equal "a.b.c", value.return_token
    assert_equal "https://www.umaxica.app/path?ok=1&x=2", value.canonical_without_return_token
  end

  test "a url without rt has no return token" do
    value = JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?ok=1")

    assert_nil value.return_token
  end

  test "a percent-encoded rt key is the literal rt key after decoding" do
    value = JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?%72t=a.b.c")

    assert_equal "a.b.c", value.return_token
  end

  ["rt=a&rt=b", "rt=a&%72t=b", "rt[]=a", "rt[x]=a", "rt%5B%5D=a", "rt=a&rt%5Bx%5D=b"].each do |query|
    test "rejects duplicate or nested rt keys in #{query}" do
      assert_nil JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?#{query}")
    end
  end

  %w(redirect_uri state nonce code next return_to).each do |key|
    test "rejects a duplicated reserved #{key} parameter" do
      assert_nil JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?#{key}=a&#{key}=b")
    end

    test "accepts a single reserved #{key} parameter" do
      assert_not_nil JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?#{key}=a")
    end
  end

  test "a duplicated non reserved parameter is kept in order" do
    value = JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?tag=b&tag=a")

    assert_equal "https://www.umaxica.app/path?tag=b&tag=a", value.canonical_without_return_token
  end

  test "space encoded as %20 or plus normalizes identically" do
    encoded = JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?q=a%20b")
    plus = JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?q=a+b")

    assert_equal "https://www.umaxica.app/path?q=a+b", encoded.canonical_without_return_token
    assert_equal encoded.canonical_without_return_token, plus.canonical_without_return_token
  end

  test "a literal plus encoded as %2B stays distinct from a space" do
    literal = JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?q=a%2Bb")
    space = JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?q=a+b")

    assert_equal "https://www.umaxica.app/path?q=a%2Bb", literal.canonical_without_return_token
    assert_not_equal literal.canonical_without_return_token, space.canonical_without_return_token
  end

  test "serializes reserved characters with URLSearchParams rules" do
    value = JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?u=https://e.example/cb?x=1&s=*-._~")

    assert_equal "https://www.umaxica.app/path?u=https%3A%2F%2Fe.example%2Fcb%3Fx%3D1&s=*-._%7E",
                 value.canonical_without_return_token
  end

  test "a key without a value serializes with an empty value" do
    value = JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?flag")

    assert_equal "https://www.umaxica.app/path?flag=", value.canonical_without_return_token
  end

  test "an empty query and a missing query share one canonical form" do
    empty = JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?")
    missing = JumpRtReturnUrlValue.parse("https://www.umaxica.app/path")

    assert_equal "https://www.umaxica.app/path", empty.canonical_without_return_token
    assert_equal "https://www.umaxica.app/path", missing.canonical_without_return_token
  end

  test "removing the only rt leaves no query" do
    value = JumpRtReturnUrlValue.parse("https://www.umaxica.app/?rt=a.b.c")

    assert_equal "https://www.umaxica.app/", value.canonical_without_return_token
    assert_equal "/", value.request_uri_without_return_token
  end

  test "request uri without return token keeps path and ordered query" do
    value = JumpRtReturnUrlValue.parse("https://www.umaxica.app/path?b=2&rt=a.b.c&a=1")

    assert_equal "/path?b=2&a=1", value.request_uri_without_return_token
  end

  test "normalizes scheme and host case and the default port" do
    value = JumpRtReturnUrlValue.parse("HTTPS://WWW.Umaxica.App:443/Path")

    assert_equal "https://www.umaxica.app/Path", value.canonical_without_return_token
  end

  test "keeps a non default port" do
    value = JumpRtReturnUrlValue.parse("https://www.umaxica.app:8443/")

    assert_equal "https://www.umaxica.app:8443/", value.canonical_without_return_token
  end

  ["http://www.umaxica.app/", "https://user@www.umaxica.app/", "https://www.umaxica.app/#frag",
   "https:///nohost", "not a url", "",].each do |url|
    test "rejects unsafe or unparsable url #{url.inspect}" do
      assert_nil JumpRtReturnUrlValue.parse(url)
    end
  end

  ["?rt=a", "?x=1&rt[]=a", "?%72t=a", "?rt%5Bx%5D=a"].each do |query|
    test "carries a return token key in #{query}" do
      assert JumpRtReturnUrlValue.carries_return_token?(query.delete_prefix("?"))
    end
  end

  ["", "x=1", "rtx=a", "art=a"].each do |query|
    test "does not carry a return token key in #{query.inspect}" do
      assert_not JumpRtReturnUrlValue.carries_return_token?(query)
    end
  end
end
