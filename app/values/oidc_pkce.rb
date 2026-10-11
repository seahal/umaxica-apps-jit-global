# typed: false
# frozen_string_literal: true

require "digest"

# Pure S256 PKCE helpers shared by authorize issuance and token exchange.
module OidcPkce
  module_function

  CODE_VERIFIER_PATTERN = /\A[A-Za-z0-9\-._~]{43,128}\z/

  def challenge_for(code_verifier)
    Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier.to_s), padding: false)
  end

  def valid_verifier?(code_verifier)
    CODE_VERIFIER_PATTERN.match?(code_verifier.to_s)
  end

  def verify(code_verifier:, code_challenge:, code_challenge_method: "S256")
    return false if code_verifier.blank? || code_challenge.blank?
    return false unless code_challenge_method.to_s == "S256"
    return false unless valid_verifier?(code_verifier)

    ActiveSupport::SecurityUtils.secure_compare(code_challenge.to_s, challenge_for(code_verifier))
  end
end
