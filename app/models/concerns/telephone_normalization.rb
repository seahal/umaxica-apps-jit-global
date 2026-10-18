# typed: false
# frozen_string_literal: true

# TelephoneNormalization
#
# Provides E.164 telephone number normalization and validation
# for all telephone-related models.
#
# E.164 Format: +[country code][subscriber number]
# - Maximum 15 digits (excluding +)
# - Example: +819012345678
#
# Input Handling:
# 1. Removes formatting characters: spaces, hyphens, parentheses, dots, slashes
# 2. Interprets international dialing prefixes (00, 010) as country code indicator
# 3. Defaults to Japan (country code 81) for domestic numbers starting with 0
# 4. Validates final E.164 format
#
# Usage:
#   include TelephoneNormalization
#   normalize_telephone_field :number  # for ClientTelephone/OperatorTelephone
#   normalize_telephone_field :telephone_number  # for ContactTelephones
#   normalize_telephone_field :body  # for TelephoneOccurrence
#
module TelephoneNormalization
  extend ActiveSupport::Concern

  # Characters to remove during normalization (formatting characters)
  FORMATTING_CHARS = [
    " ", # Half-width space
    "\u3000", # Full-width space
    "-", # Hyphen-minus
    "‐", # Hyphen
    "−", # Minus sign
    "–", # En dash
    "—", # Em dash
    "(", # Left parenthesis
    ")", # Right parenthesis
    "（", # Full-width left parenthesis
    "）", # Full-width right parenthesis
    ".", # Period
    "/", # Slash
    "・", # Middle dot
  ].freeze

  # E.164 format regex: + followed by country code (1-9) and 1-14 more digits
  E164_FORMAT = /\A\+[1-9]\d{1,14}\z/

  # Maximum total digits in E.164 (excluding +)
  MAX_E164_DIGITS = 15

  # Default country code (Japan)
  DEFAULT_COUNTRY_CODE = "81"

  class_methods do
    # Define which field to normalize
    # @param field_name [Symbol] the field name to normalize (:number, :telephone_number, :body)
    def normalize_telephone_field(field_name)
      before_validation do
        normalized = TelephoneNormalization.normalize_to_e164(public_send(field_name))
        public_send("#{field_name}=", normalized)
      end

      validates field_name,
                presence: true,
                format: {
                  with: E164_FORMAT,
                  message: :invalid_e164_format,
                },
                length: {
                  maximum: 16, # +[15 digits]

                }
    end
  end

  # Normalize a telephone number to E.164 format
  #
  # @param raw_input [String, nil] the raw telephone input
  # @return [String, nil] normalized E.164 format or nil if invalid
  def self.normalize_to_e164(raw_input)
    return nil if raw_input.blank?

    # Step 1: Remove all formatting characters
    cleaned = remove_formatting_characters(raw_input.to_s)

    # Step 2: Return nil if no digits remain
    return nil if cleaned.blank? || cleaned.delete("^0-9+").blank?

    # Step 3: Handle international dialing prefixes (00, 010)
    # Returns [cleaned_number, was_converted_from_prefix]
    cleaned, from_intl_prefix = convert_international_prefix(cleaned)

    # Step 4: Handle domestic format (starts with 0 but not +)
    # Pass the flag to know if we should remove domestic 0 after country code
    convert_domestic_format(cleaned, from_intl_prefix)
  end

  # Remove formatting characters from input
  # @param input [String] the raw input
  # @return [String] input without formatting characters
  def self.remove_formatting_characters(input)
    result = input.dup
    FORMATTING_CHARS.each { |char| result.gsub!(char, "") }
    result
  end

  private_class_method :remove_formatting_characters

  # Convert international dialing prefixes (00, 010) to +
  # Also removes domestic 0 if present after country code
  # Examples:
  #   "0081901234567" -> ["+8190123456 7", true]
  #   "00810901234567" -> ["+819012345678", true] (domestic 0 removed)
  #   "010819012345678" -> ["+819012345678", true]
  #   "01081090..." -> ["+8190...", true] (domestic 0 removed)
  #   "+819012345678" -> ["+819012345678", false]
  #
  # @param input [String] cleaned number
  # @return [Array<String, Boolean>] [number with + prefix, was_converted_from_prefix]
  def self.convert_international_prefix(input)
    # Handle "010" prefix (Japan international dialing)
    if input.start_with?("010")
      result = "+" + input[3, input.length].to_s
      # Remove domestic 0 after country code if present
      # Pattern: +[1-3 digits]0[1-9...]
      result = remove_domestic_zero_after_country_code(result)
      return [result, true]
    end

    # Handle "00" prefix (international dialing in many countries)
    if input.start_with?("00")
      result = "+" + input[2, input.length].to_s
      # Remove domestic 0 after country code if present
      result = remove_domestic_zero_after_country_code(result)
      return [result, true]
    end

    [input, false]
  end

  private_class_method :convert_international_prefix

  # Remove domestic 0 after country code
  # Example: "+81090..." -> "+8190..."
  # @param input [String] number with + prefix
  # @return [String] number with domestic 0 removed if applicable
  def self.remove_domestic_zero_after_country_code(input)
    # Common country codes and their patterns
    # Japan (+81): domestic numbers start with 0
    # US/Canada (+1): no domestic 0
    # UK (+44): domestic numbers start with 0
    # etc.

    # For Japan (+81): remove 0 after country code
    # Pattern: +810... where the next digit after 0 is 1-9
    if input.start_with?("+81") && input.length >= 6
      # Check if there's a 0 right after +81
      if input[3] == "0" && input[4].match?(/[1-9]/)
        return "+81" + input[4, input.length].to_s
      end

      return input
    end

    # For other 2-digit country codes ending in non-1 digits
    # Try to detect pattern +XX0[1-9]...
    if input =~ /\A(\+\d{2})0([1-9]\d{7,})\z/
      return "#{::Regexp.last_match(1)}#{::Regexp.last_match(2)}"
    end

    # For 1-digit country codes (like +1 for US)
    # US doesn't have domestic 0, but other +1 countries might
    if input =~ /\A(\+\d)0([1-9]\d{7,})\z/
      return "#{::Regexp.last_match(1)}#{::Regexp.last_match(2)}"
    end

    # For 3-digit country codes
    if input =~ /\A(\+\d{3})0([1-9]\d{7,})\z/
      return "#{::Regexp.last_match(1)}#{::Regexp.last_match(2)}"
    end

    # No domestic 0 found or pattern doesn't match
    input
  end

  private_class_method :remove_domestic_zero_after_country_code

  # Convert domestic format to E.164 with default country code (Japan: +81)
  # Domestic format: starts with 0 (but not already with +)
  #
  # Examples:
  #   "09012345678" -> "+819012345678"
  #   "0312345678" -> "+81312345678"
  #
  # Special case: If input came from international prefix conversion (00, 010) and still
  # has a leading 0 after country code (e.g., +81090...), remove that 0
  #
  # @param input [String] cleaned number
  # @param from_intl_prefix [Boolean] whether this was converted from 00/010 prefix
  # @return [String] number in international format
  def self.convert_domestic_format(input, _from_intl_prefix)
    # Already has + prefix (international format)
    # If it came from international prefix, domestic 0 was already removed
    return input if input.start_with?("+")

    # Domestic format: starts with 0
    if input.start_with?("0")
      # Remove leading 0 and add +81
      return "+#{DEFAULT_COUNTRY_CODE}#{input[1, input.length]}"
    end

    # No + and doesn't start with 0: invalid (ambiguous)
    # Return as-is and let validation fail
    input
  end

  private_class_method :convert_domestic_format
end
