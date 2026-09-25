# typed: false
# frozen_string_literal: true

class AvatarMonikerValidator < ActiveModel::EachValidator
  MAX_BYTES = 128
  MAX_GRAPHEME_CLUSTERS = 16

  def validate(record)
    attributes.each do |attribute|
      validate_each(record, attribute, record.read_attribute_for_validation(attribute))
    end
  end

  def validate_each(record, attribute, value)
    if value.nil?
      record.errors.add(attribute, :blank)
      return
    end

    unless value.is_a?(String) && value.encoding == Encoding::UTF_8 && value.valid_encoding?
      record.errors.add(attribute, :invalid)
      return
    end

    if value.empty? || value.match?(/\A\p{Space}*\z/u)
      record.errors.add(attribute, :blank)
      return
    end

    if value.match?(/\A\p{Space}|\p{Space}\z/u)
      record.errors.add(attribute, :invalid)
      return
    end

    if value.bytesize > MAX_BYTES
      record.errors.add(attribute, :too_long, count: MAX_BYTES)
      return
    end

    if forbidden_codepoint?(value)
      record.errors.add(attribute, :invalid)
      return
    end

    return unless grapheme_cluster_count(value) > MAX_GRAPHEME_CLUSTERS

    record.errors.add(attribute, :too_long, count: MAX_GRAPHEME_CLUSTERS)
  end

  def check_validity!
    return unless options[:allow_nil] || options[:allow_blank]

    raise ArgumentError, "Avatar monikers cannot allow nil or blank values"
  end

  private

  def forbidden_codepoint?(value)
    value.each_codepoint.any? do |codepoint|
      codepoint <= 0x1f ||
        codepoint.between?(0x7f, 0x9f) ||
        codepoint.between?(0x2028, 0x2029) ||
        codepoint == 0x200b ||
        codepoint == 0xfeff ||
        bidi_control?(codepoint)
    end
  end

  def bidi_control?(codepoint)
    codepoint == 0x061c ||
      codepoint.between?(0x200e, 0x200f) ||
      codepoint.between?(0x202a, 0x202e) ||
      codepoint.between?(0x2066, 0x2069)
  end

  def grapheme_cluster_count(value)
    count = 0
    value.each_grapheme_cluster do
      count += 1
      break if count > MAX_GRAPHEME_CLUSTERS
    end
    count
  end
end
