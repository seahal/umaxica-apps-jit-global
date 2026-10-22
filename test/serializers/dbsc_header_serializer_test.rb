# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../app/serializers/dbsc_header_serializer"
require_relative "../../app/values/dbsc_header_parser"

class DbscHeaderSerializerTest < Minitest::Test
  def test_serializes_challenge_and_escapes_identifier_parameter_delimiters
    value = DbscHeaderSerializer.challenge(challenge: 'c"\\', session_id: 's";extra="v')

    assert_equal '"c\\"\\\\";id="s\\";extra=\\"v"', value
    assert_equal 'c"\\', DbscHeaderParser.string_value(value)
  end

  def test_serializes_registration_with_individually_quoted_values
    assert_equal '(ES256 RS256);path="/register";challenge="c\\"\\\\"',
                 DbscHeaderSerializer.registration(path: "/register", challenge: 'c"\\')
  end

  def test_round_trips_every_printable_ascii_character
    (0x20..0x7e).each do |byte|
      value = byte.chr

      assert_equal value, DbscHeaderParser.string_value(DbscHeaderSerializer.string(value)), byte.to_s
    end
    assert_equal '""', DbscHeaderSerializer.string("")
  end

  def test_rejects_non_ascii_control_and_non_string_values_without_disclosing_them
    [nil, 0, false, [], {}, "\x1f", "\x7f", "\x80".b, "\u0080", "dummy\r\nInjected: true"].each do |value|
      error = assert_raises(ArgumentError) { DbscHeaderSerializer.string(value) }
      assert_equal "DBSC header string must contain printable ASCII only", error.message
    end
  end

  def test_requires_nonempty_challenge_and_identifier
    [nil, ""].each do |value|
      assert_raises(ArgumentError) { DbscHeaderSerializer.challenge(challenge: value, session_id: "session") }
      assert_raises(ArgumentError) { DbscHeaderSerializer.challenge(challenge: "challenge", session_id: value) }
    end
  end
end
