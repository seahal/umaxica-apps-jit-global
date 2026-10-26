# frozen_string_literal: true

# D-135: whether a sign-up contact's destination is still held by an unfinished registration
# (D-131: the owner has not reached its registered status) whose contact cleanup has not retired.
# Callers run it under the destination's SignUpEmailPendingGuard lock so the answer cannot race a
# concurrent candidate creation for the same digest.
class SignUpContactHoldQuery
  class << self
    public

    def call(contact:)
      model, digest_column, status_column, deleted_status_id, owner_model, owner_key = components(contact)
      digest = contact.public_send(digest_column)
      raise ArgumentError, "sign-up contact requires a destination digest" if digest.blank?

      unfinished_owner_ids = owner_model.where(status_id: owner_model::UNFINISHED_REGISTRATION_STATUS_IDS).select(:id)
      model
        .where(digest_column => digest)
        .where.not(status_column => deleted_status_id)
        .exists?(owner_key => unfinished_owner_ids)
    end

    private

    def components(contact)
      case contact
      when ClientEmail
        [ClientEmail, :address_digest, :user_email_status_id, ClientEmailStatus::DELETED, Client, :user_id]
      when ClientTelephone
        [ClientTelephone, :number_digest, :user_identity_telephone_status_id, ClientTelephoneStatus::DELETED, Client,
         :user_id,]
      when VisitorEmail
        [VisitorEmail, :address_digest, :visitor_email_status_id, VisitorEmailStatus::DELETED, Visitor, :visitor_id]
      when VisitorTelephone
        [VisitorTelephone, :number_digest, :visitor_telephone_status_id, VisitorTelephoneStatus::DELETED, Visitor,
         :visitor_id,]
      else raise ArgumentError, "unsupported sign-up contact"
      end
    end
  end
end
