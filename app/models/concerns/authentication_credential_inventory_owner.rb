# typed: false
# frozen_string_literal: true

module AuthenticationCredentialInventoryOwner
  extend ActiveSupport::Concern

  include AuthenticationContactabilityOwner

  def authentication_credential_inventory(excluding: nil, reload: false)
    AuthenticationCredentialInventory.call(self, excluding: excluding, reload: reload)
  end

  def sign_in_methods(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).sign_in_methods
  end

  def usable_sign_in_capabilities(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).usable_sign_in_capabilities
  end

  def has_usable_sign_in_capability?(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).has_usable_sign_in_capability?
  end

  def step_up_methods(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).step_up_methods
  end

  def usable_step_up_capabilities(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).usable_step_up_capabilities
  end

  def has_usable_step_up_capability?(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).has_usable_step_up_capability?
  end

end
