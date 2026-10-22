# frozen_string_literal: true

# W3C DBSC sections 9.1/9.2 and RFC 9651 section 4.1.6.
module DbscHeaderSerializer
  module_function

  def string(value)
    unless value.is_a?(String) && value.valid_encoding? && value.match?(/\A[\x20-\x7e]*\z/)
      raise ArgumentError, "DBSC header string must contain printable ASCII only"
    end

    '"' + value.gsub(/["\\]/) { |character| "\\#{character}" } + '"'
  end

  def challenge(challenge:, session_id:)
    unless challenge.is_a?(String) && !challenge.empty? && session_id.is_a?(String) && !session_id.empty?
      raise ArgumentError, "DBSC challenge and session id are required"
    end

    "#{string(challenge)};id=#{string(session_id)}"
  end

  def registration(path:, challenge:)
    "(ES256 RS256);path=#{string(path)};challenge=#{string(challenge)}"
  end
end
