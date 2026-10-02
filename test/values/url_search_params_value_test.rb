# frozen_string_literal: true

require "test_helper"

class UrlSearchParamsValueTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "parses pairs in order with repeated keys kept" do
    params = UrlSearchParamsValue.parse("b=2&a=1&b=3")

    assert_equal [["b", "2"], ["a", "1"], ["b", "3"]], params.pairs
    assert_equal %w(b a b), params.keys
  end

  test "decodes plus as space and percent sequences in keys and values" do
    params = UrlSearchParamsValue.parse("%73tate=a+b&q=a%2Bb")

    assert_equal [["state", "a b"], ["q", "a+b"]], params.pairs
  end

  test "leaves an invalid percent sequence undecoded" do
    assert_equal [["q", "%zz"]], UrlSearchParamsValue.parse("q=%zz").pairs
  end

  test "replaces invalid utf-8 bytes with the replacement character" do
    assert_equal [["q", "�"]], UrlSearchParamsValue.parse("q=%FF").pairs
  end

  test "a key without equals has an empty value and empty segments are skipped" do
    assert_equal [["flag", ""], ["a", "1"]], UrlSearchParamsValue.parse("&flag&&a=1&").pairs
  end

  [nil, ""].each do |raw|
    test "#{raw.inspect} parses to no pairs" do
      params = UrlSearchParamsValue.parse(raw)

      assert_empty params
      assert_equal "", params.to_s
    end
  end

  test "serializes with URLSearchParams rules" do
    params = UrlSearchParamsValue.parse("u=https://e.example/cb?x=1&s=*-._~&sp=a%20b&k=%E3%81%82")

    assert_equal "u=https%3A%2F%2Fe.example%2Fcb%3Fx%3D1&s=*-._%7E&sp=a+b&k=%E3%81%82", params.to_s
  end

  test "reject keys returns a new value and keeps the original" do
    params = UrlSearchParamsValue.parse("a=1&rt=x&b=2")

    remaining = params.reject_keys { |key| key == "rt" }

    assert_equal "a=1&b=2", remaining.to_s
    assert_equal "a=1&rt=x&b=2", params.to_s
  end

  test "rejecting every key leaves an empty value" do
    assert_empty UrlSearchParamsValue.parse("rt=x").reject_keys { |key| key == "rt" }
  end
end
