# frozen_string_literal: true

# Identifier-first Passkey sign-in (adr/passkey-identifier-first-sign-in.md) on APP and COM:
# resolves the entered Email or Telephone to exactly one Identity through effective contact
# bindings of that surface only. Unknown, ambiguous and malformed identifiers all return nil, so
# the caller answers them like a real Identity without a usable Passkey.
class PasskeySignInIdentityResolverQuery
  CONTACTS = {
    app: [ClientEmail, ClientTelephone, :user],
    com: [VisitorEmail, VisitorTelephone, :visitor],
  }.freeze

  class << self
    public

    def call(surface:, identifier:)
      email_model, telephone_model, owner = CONTACTS.fetch(surface)
      return nil unless identifier.is_a?(String) && identifier.valid_encoding? && identifier.exclude?("\0")

      owners = []
      email_digest = IdentifierBlindIndex.bidx_for_email(identifier, realm: surface)
      if email_digest
        email = email_model.effective_binding.find_by(address_digest: email_digest)
        owners << owner_of(email, owner) if email
      end

      telephone_digest = IdentifierBlindIndex.bidx_for_telephone(identifier, realm: surface)
      if telephone_digest
        telephone = telephone_model.effective_binding.find_by(number_digest: telephone_digest)
        owners << owner_of(telephone, owner) if telephone
      end

      owners.compact!
      owners.uniq!(&:id)
      owners.one? ? owners.first : nil
    rescue ArgumentError, EncodingError
      nil
    end

    private

    def owner_of(contact, association)
      contact.association(association).tap { |owner| owner.reset_scope }.scope.take
    end
  end
end
