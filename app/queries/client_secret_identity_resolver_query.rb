# frozen_string_literal: true

# Resolves the non-secret sign-in identifier to exactly one effective app
# Client. Candidate contacts and every other surface are intentionally outside
# this query, so a failed lookup has the same non-disclosing result as a wrong
# Secret.
class ClientSecretIdentityResolverQuery
  class << self
    def call(identifier:)
      return nil unless identifier.is_a?(String) && identifier.valid_encoding? && identifier.exclude?("\0")

      clients = []
      email_digest = IdentifierBlindIndex.bidx_for_email(identifier)
      if email_digest
        clients << ClientEmail.effective_binding.find_by(address_digest: email_digest)&.user
      end

      telephone_digest = IdentifierBlindIndex.bidx_for_telephone(identifier)
      if telephone_digest
        clients << ClientTelephone.effective_binding.find_by(number_digest: telephone_digest)&.user
      end

      clients = clients.compact.uniq(&:id)
      clients.one? ? clients.first : nil
    rescue ArgumentError, EncodingError
      nil
    end
  end
end
