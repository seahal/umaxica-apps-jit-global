# frozen_string_literal: true

# Identifier-first Passkey sign-in (adr/passkey-identifier-first-sign-in.md) on APP and COM:
# resolves the entered Email or Telephone to exactly one Identity through effective contact
# bindings of that surface only. Unknown, ambiguous and malformed identifiers all return nil, so
# the caller answers them like a real Identity without a usable Passkey.
class PasskeySignInIdentityResolverQuery
  CONTACTS = {
    app: {
      email: ClientEmail,
      telephone: ClientTelephone,
      owner: :user,
      email_status_column: :user_email_status_id,
      email_status_ids: [ClientEmailStatus::VERIFIED, ClientEmailStatus::VERIFIED_WITH_SIGN_UP].freeze,
      telephone_status_column: :user_telephone_status_id,
      telephone_status_ids: [ClientTelephoneStatus::VERIFIED, ClientTelephoneStatus::VERIFIED_WITH_SIGN_UP].freeze,
    }.freeze,
    com: {
      email: VisitorEmail,
      telephone: VisitorTelephone,
      owner: :visitor,
      email_status_column: :visitor_email_status_id,
      email_status_ids: [VisitorEmailStatus::VERIFIED, VisitorEmailStatus::VERIFIED_WITH_SIGN_UP].freeze,
      telephone_status_column: :visitor_telephone_status_id,
      telephone_status_ids: [VisitorTelephoneStatus::VERIFIED, VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP].freeze,
    }.freeze,
  }.freeze

  class << self
    public

    def call(surface:, identifier:)
      contacts = CONTACTS.fetch(surface)
      return nil unless identifier.is_a?(String) && identifier.valid_encoding? && identifier.exclude?("\0")

      owners = []
      email_digest = IdentifierBlindIndex.bidx_for_email(identifier, realm: surface)
      if email_digest
        email = find_effective_contact(
          contacts.fetch(:email),
          digest_column: :address_digest,
          digest: email_digest,
          status_column: contacts.fetch(:email_status_column),
          status_ids: contacts.fetch(:email_status_ids),
        )
        owners << owner_of(email, contacts.fetch(:owner)) if email
      end

      telephone_digest = IdentifierBlindIndex.bidx_for_telephone(identifier, realm: surface)
      if telephone_digest
        telephone = find_effective_contact(
          contacts.fetch(:telephone),
          digest_column: :number_digest,
          digest: telephone_digest,
          status_column: contacts.fetch(:telephone_status_column),
          status_ids: contacts.fetch(:telephone_status_ids),
        )
        owners << owner_of(telephone, contacts.fetch(:owner)) if telephone
      end

      owners.compact!
      owners.uniq!(&:id)
      owners.one? ? owners.first : nil
    rescue ArgumentError, EncodingError
      nil
    end

    private

    def find_effective_contact(model, digest_column:, digest:, status_column:, status_ids:)
      model.effective_binding
        .where(status_column => status_ids)
        .where("discard_at > ?", model.database_now)
        .find_by(digest_column => digest)
    end

    def owner_of(contact, association)
      contact.association(association).tap { |owner| owner.reset_scope }.scope.take
    end
  end
end
