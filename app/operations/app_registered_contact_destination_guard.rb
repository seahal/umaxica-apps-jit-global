# frozen_string_literal: true

class AppRegisteredContactDestinationGuard
  class RegisteredDestinationIncident < RuntimeError; end

  class << self
    public

    def with_lock(contact:, owner:)
      model, digest_column, namespace, digest, contact_owner_id = components(contact, owner)
      return yield(false) unless contact_owner_id == owner.id

      SignUpEmailPendingGuard.with_lock(
        **{ digest_column => digest }, namespace: namespace, model_class: model,
      ) do
        yield registered_contact_owned_by_other?(model:, digest_column:, digest:, owner:)
      end
    end

    def with_available_destination(contact:, owner:)
      with_lock(contact: contact, owner: owner) do |registered|
        raise RegisteredDestinationIncident, "APP contact destination is already registered" if registered

        yield
      end
    end

    def registered_by_other_owner?(contact:, owner:)
      model, digest_column, _namespace, digest, contact_owner_id = components(contact, owner)
      return false unless contact_owner_id == owner.id

      registered_contact_owned_by_other?(model:, digest_column:, digest:, owner:)
    end

    private

    def registered_contact_owned_by_other?(model:, digest_column:, digest:, owner:)
      model.effective_binding.where(digest_column => digest).where.not(user_id: owner.id).exists?
    end

    def components(contact, owner)
      case [contact, owner]
      in [ClientEmail, Client]
        [
          ClientEmail, :address_digest, SignUpEmailPendingGuard::EMAIL_NAMESPACE, contact.address_digest,
          contact.user_id,
        ]
      in [ClientTelephone, Client]
        [
          ClientTelephone, :number_digest, SignUpEmailPendingGuard::TELEPHONE_NAMESPACE, contact.number_digest,
          contact.user_id,
        ]
      else
        raise ArgumentError, "unsupported APP registered destination candidate"
      end
    end
  end
end
