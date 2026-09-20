# typed: false
# frozen_string_literal: true

class AuthMethodGuard
  VERIFIED_EMAIL_STATUSES = [
    ClientEmailStatus::VERIFIED,
    ClientEmailStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  VERIFIED_TELEPHONE_STATUSES = [
    ClientTelephoneStatus::VERIFIED,
    ClientTelephoneStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  VISITOR_VERIFIED_EMAIL_STATUSES = [
    VisitorEmailStatus::VERIFIED,
    VisitorEmailStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  VISITOR_VERIFIED_TELEPHONE_STATUSES = [
    VisitorTelephoneStatus::VERIFIED,
    VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze

  def self.remaining_count(actor, excluding: nil)
    AuthenticationCredentialInventory.call(actor, excluding: excluding, reload: true).aal1_method_count
  end

  def self.last_method?(actor, excluding: nil)
    remaining_count(actor, excluding: excluding).zero?
  end

  def self.can_remove_passkey?(actor, passkey)
    inventory = AuthenticationCredentialInventory.call(actor, excluding: passkey, reload: true)
    inventory.retains_aal1? && inventory.retains_uv_step_up?
  end

  def self.can_remove_email?(actor, email)
    inventory = AuthenticationCredentialInventory.call(actor, excluding: email, reload: true)
    inventory.retains_contactability? && inventory.retains_aal1? && inventory.retains_uv_step_up?
  end

  def self.can_remove_telephone?(actor, telephone)
    AuthenticationCredentialInventory.call(actor, excluding: telephone, reload: true).retains_contactability?
  end

  def self.can_remove_totp?(actor, totp)
    AuthenticationCredentialInventory.call(actor, excluding: totp, reload: true).retains_uv_step_up?
  end

  def self.can_remove_secret_credential?(actor, secret_credential)
    AuthenticationCredentialInventory.call(actor, excluding: secret_credential, reload: true).retains_aal1?
  end
end
