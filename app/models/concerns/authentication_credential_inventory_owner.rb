# typed: false
# frozen_string_literal: true

module AuthenticationCredentialInventoryOwner
  extend ActiveSupport::Concern

  include AuthenticationContactabilityOwner

  def authentication_credential_inventory(excluding: nil, reload: false)
    AuthenticationCredentialInventory.call(self, excluding: excluding, reload: reload)
  end

  def authentication_method_inventory(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload)
  end

  def sign_in_methods(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).sign_in_methods
  end

  def login_methods(excluding: nil, reload: false)
    sign_in_methods(excluding: excluding, reload: reload)
  end

  def sign_in_method_count(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).sign_in_method_count
  end

  def sign_in_available?(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).sign_in_available?
  end

  def retains_sign_in_after?(excluding:, reload: false)
    sign_in_available?(excluding: excluding, reload: reload)
  end

  def retains_login_after?(excluding:, reload: false)
    retains_sign_in_after?(excluding: excluding, reload: reload)
  end

  def step_up_methods(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).step_up_methods
  end

  def step_up_available?(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).step_up_available?
  end

  def retains_step_up_after?(excluding:, reload: false)
    step_up_available?(excluding: excluding, reload: reload)
  end
end
