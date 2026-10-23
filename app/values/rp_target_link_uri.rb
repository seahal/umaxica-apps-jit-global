# typed: false
# frozen_string_literal: true

# The RP's own return target (D-151): a relative path on the RP's host with no query, no fragment,
# no dot segment, no encoded separator and nothing under `/sign` or `/oidc`. Anything else is
# ignored and the RP default page is used.
module RpTargetLinkUri
  module_function

  PATH_PATTERN = %r{\A/[A-Za-z0-9\-._~/!$&'()*+,;=:@]*\z}
  FORBIDDEN_PREFIXES = %w(/sign /oidc).freeze

  def normalize(value)
    path = value.to_s
    return nil unless path.match?(PATH_PATTERN)
    return nil if path.start_with?("//") || path.include?("%")
    return nil if path.split("/").any? { |segment| %w(. ..).include?(segment) }
    return nil if FORBIDDEN_PREFIXES.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") }

    path
  end
end
