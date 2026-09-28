# typed: false
# frozen_string_literal: true

# Reads a browser credential cookie as a String that string predicates can inspect. Rack hands
# over the raw bytes, and a value with an invalid byte sequence raises ArgumentError on `blank?`
# or `split`, which turned a malformed client credential into a 500. Replacing the invalid bytes
# keeps the value unparseable, so it is refused as malformed like any other garbage value.
module BrowserCredentialCookie
  module_function

  def read(cookies, name)
    value = cookies[name]
    return value if value.nil?

    value = value.to_s
    value.valid_encoding? ? value : value.scrub
  end
end
