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

  def self.can_remove_passkey?(actor, passkey)
    preserves_required_capabilities?(actor, passkey)
  end

  def self.can_remove_email?(actor, email)
    preserves_required_capabilities?(actor, email)
  end

  def self.can_remove_telephone?(actor, telephone)
    preserves_required_capabilities?(actor, telephone)
  end

  def self.can_remove_totp?(actor, totp)
    preserves_required_capabilities?(actor, totp)
  end

  def self.can_remove_secret_credential?(actor, secret_credential)
    preserves_required_capabilities?(actor, secret_credential)
  end

  def self.can_remove_external_identity?(actor, external_identity)
    preserves_required_capabilities?(actor, external_identity)
  end

  def self.preserves_required_capabilities?(actor, excluding)
    before = AuthenticationCredentialInventory.call(actor, reload: true)
    after = AuthenticationCredentialInventory.call(actor, excluding: excluding, reload: true)

    capability_survives?(before.has_usable_sign_in_capability?, after.has_usable_sign_in_capability?) &&
      capability_survives?(before.has_usable_step_up_capability?, after.has_usable_step_up_capability?)
  end

  private_class_method :preserves_required_capabilities?

  def self.capability_survives?(was_available, remains_available)
    !was_available || remains_available
  end

  private_class_method :capability_survives?
end
