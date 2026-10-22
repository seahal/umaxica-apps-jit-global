# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../../app/values/dbsc_header_parser"

class DbscHeaderParserTest < Minitest::Test
  def test_parses_a_string_with_http_whitespace
    assert_equal "session-123", DbscHeaderParser.string_value(" \t\"session-123\"\t ")
    assert_equal "", DbscHeaderParser.string_value('""')
  end

  def test_decodes_only_quote_and_backslash_escapes
    assert_equal 'a"b\\c', DbscHeaderParser.string_value('"a\\"b\\\\c"')
    assert_equal 's";extra="v', DbscHeaderParser.string_value('"s\\";extra=\\"v"')
  end

  def test_ignores_valid_parameters_without_treating_them_as_identifier_content
    assert_equal "session", DbscHeaderParser.string_value('"session";ignored="value";flag;number=12;token=abc')
    ["-1", "1.25", "?0", "@123", ":YWJj:", '%"hello%20world"'].each do |value|
      assert_equal "session", DbscHeaderParser.string_value(%("session";ignored=#{value})), value
    end
  end

  def test_rejects_missing_non_string_unquoted_and_malformed_fields
    [nil, false, 0, [], {}, "", " ", "session", '"unterminated', '"bad\\n"',
     '"session"junk', '"session", "other"', '"s";extra="v',
     '"session";=bad', '"session";bad=', '"session";bad=?2',].each do |value|
      assert_nil DbscHeaderParser.string_value(value), value.inspect
    end
  end

  def test_enforces_rfc_numeric_parameter_width_boundaries
    [14, 15].each do |digits|
      assert_equal "session", DbscHeaderParser.string_value(%("session";ignored=#{"1" * digits}))
      assert_equal "session", DbscHeaderParser.string_value(%("session";ignored=@#{"1" * digits}))
    end
    assert_nil DbscHeaderParser.string_value(%("session";ignored=#{"1" * 16}))
    assert_nil DbscHeaderParser.string_value(%("session";ignored=@#{"1" * 16}))

    [11, 12].each do |digits|
      assert_equal "session", DbscHeaderParser.string_value(%("session";ignored=#{"1" * digits}.1))
    end
    assert_nil DbscHeaderParser.string_value(%("session";ignored=#{"1" * 13}.1))

    [2, 3].each do |digits|
      assert_equal "session", DbscHeaderParser.string_value(%("session";ignored=1.#{"1" * digits}))
    end
    assert_nil DbscHeaderParser.string_value('"session";ignored=1.1111')
  end

  def test_accepts_printable_ascii_boundaries_and_rejects_adjacent_controls
    # Quote and backslash are reachable only through their escaped representations.
    [0x20, 0x21, 0x23, 0x5b, 0x5d, 0x7d, 0x7e].each do |byte|
      assert_equal byte.chr, DbscHeaderParser.string_value('"' + byte.chr + '"'), byte.to_s
    end
    [0, 0x1f, 0x7f, 0x80, 0xff].each do |byte|
      assert_nil DbscHeaderParser.string_value('"' + byte.chr + '"'), byte.to_s
    end
    assert_nil DbscHeaderParser.string_value("\"a\r\nInjected: value\"")
    assert_nil DbscHeaderParser.string_value("\"a\";ignored=\"b\nc\"")
    assert_nil DbscHeaderParser.string_value("\"a\"\r\n")
    assert_nil DbscHeaderParser.string_value("\"\u0080\"")
  end
end
