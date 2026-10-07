# typed: false
# frozen_string_literal: true

module MfaStatusCredential
  extend ActiveSupport::Concern

  OWNER_ASSOCIATIONS = Concurrent::Map.new

  included { after_commit :refresh_owner_mfa_status }

  class_methods do
    def mfa_status_owner(association_name)
      OWNER_ASSOCIATIONS[self] = association_name
    end

    def mfa_status_owner_association
      OWNER_ASSOCIATIONS.fetch(self)
    end
  end

  private

  def refresh_owner_mfa_status
    owner = public_send(self.class.mfa_status_owner_association)
    return unless owner&.respond_to?(:refresh_mfa_status!)
    return if owner.destroyed?

    # Credential commits can follow an owner promotion in the same transaction.
    # Load persisted state under the owner lock without saving or discarding cached edits.
    operation =
      lambda do
        owner.class.transaction do
          owner.class.lock.find(owner.id).refresh_mfa_status!
        end
      end
    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end
end
