# typed: false
# frozen_string_literal: true

module DbscHeaderParser
  # RFC 9651 sf-string and bare parameter values. Unknown parameters are validated
  # and discarded; neither list members nor trailing input are part of this field.
  STRING = /"(?:[\x20-\x21\x23-\x5b\x5d-\x7e]|\\["\\])*"/.freeze
  PARAMETER_VALUE = %r{
    (?:#{STRING}|-?[0-9]{1,12}\.[0-9]{1,3}|-?[0-9]{1,15}|\?[01]|@-?[0-9]{1,15}|
    :[A-Za-z0-9+/=]*:|%"(?:[\x20-\x21\x23-\x24\x26-\x7e]|%[0-9A-Fa-f]{2})*"|
    [A-Za-z*][A-Za-z0-9!\#$%&'*+\-.^_`|~:/]*)
  }x.freeze
  FIELD = /\A[ \t]*(?<string>#{STRING})(?:; *[a-z*][a-z0-9_.*-]*(?:=#{PARAMETER_VALUE})?)*[ \t]*\z/.freeze
  private_constant :STRING, :PARAMETER_VALUE, :FIELD

  module_function

  def string_value(value)
    return unless value.is_a?(String) && value.valid_encoding? && value.ascii_only?

    match = FIELD.match(value)
    return unless match

    match[:string][1...-1].gsub(/\\(["\\])/, '\1')
  end
end
