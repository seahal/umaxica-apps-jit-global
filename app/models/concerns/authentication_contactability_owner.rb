# typed: false
# frozen_string_literal: true

module AuthenticationContactabilityOwner
  extend ActiveSupport::Concern

  def contact_identifiers(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).contact_identifiers
  end

  def contact_identifier_count(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).contact_identifier_count
  end

  def has_contact_identifier?(excluding: nil, reload: false)
    contact_identifiers(excluding: excluding, reload: reload).any?
  end
end
