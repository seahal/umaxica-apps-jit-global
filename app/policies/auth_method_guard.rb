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

  # Consolidation ADR 2.2: an ADVANCED actor keeps at least two active Passkeys; a deletion from two
  # to one is refused whatever authentication preceded it. Callers evaluate this under the owner lock.
  def self.can_remove_passkey?(actor, passkey)
    return false if actor.security_mode_advanced? && active_passkeys_remaining(actor, passkey) < 2

    preserves_required_capabilities?(actor, passkey)
  end

  def self.active_passkeys_remaining(actor, passkey)
    surface = Webauthn::Surface.for({ Client => :app, Visitor => :com, Operator => :org }.fetch(actor.class))
    surface.passkey_class.where(
      surface.actor_foreign_key => actor.id,
      :status_id => surface.passkey_status_class::ACTIVE,
    )
      .where.not(id: passkey.id).count
  end

  private_class_method :active_passkeys_remaining

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
