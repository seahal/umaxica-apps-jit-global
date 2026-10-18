# typed: false
# frozen_string_literal: true

# An ordered list of decoded query pairs with WHATWG application/x-www-form-urlencoded parsing and
# URLSearchParams serialization. Rack's Hash-based parsers drop order and repeated pairs; Jump RT
# issuance and return verification must keep both, because the signed `url` claim binds them.
class UrlSearchParamsValue
  class << self
    public

    def parse(raw_query)
      pairs =
        raw_query.to_s.split("&").filter_map do |segment|
          next if segment.empty?

          key, value = segment.split("=", 2)
          [decode_component(key), decode_component(value.to_s)].freeze
        end
      new(pairs)
    end

    private

    def decode_component(component)
      bytes = component.tr("+", " ").b.gsub(/%([0-9A-Fa-f]{2})/) { Regexp.last_match(1).hex.chr }
      bytes.force_encoding(Encoding::UTF_8).scrub.freeze
    end
  end

  def initialize(pairs)
    @pairs = pairs.freeze
    freeze
  end

  public

  attr_reader :pairs

  def keys
    pairs.map(&:first)
  end

  def reject_keys(&)
    self.class.new(pairs.reject { |key, _value| yield(key) })
  end

  delegate :empty?, to: :pairs

  def to_s
    pairs.map { |key, value| "#{serialize_component(key)}=#{serialize_component(value)}" }.join("&")
  end

  private

  # URLSearchParams leaves only *-._ and alphanumerics unescaped; 0x20 becomes "+".
  def serialize_component(component)
    component.b.gsub(/[^*\-._0-9A-Za-z]/n) { |byte| (byte == " ") ? "+" : format("%%%02X", byte.ord) }
  end
end
