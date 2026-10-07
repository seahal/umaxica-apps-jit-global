# typed: false
# frozen_string_literal: true

# Authorization for the app (client) email listing.
#
# `Sign::App::Settings::EmailsController` and its registration subcontroller scope every
# query to `current_client.client_emails`, so row-level ownership is enforced by those queries.
# `index?`/`create?` gate the actor *type*; the per-record write rules require ownership
# (record.user_id == client.id). Other defaults stay deny-all (allowlist).
class ClientEmailPolicy < ApplicationPolicy
  def index?
    user.is_a?(Client)
  end

  # Registration (new/create) is a fresh, unsaved record; gate by actor type. new? aliases create?.
  def create?
    user.is_a?(Client)
  end

  # Per-record management of an owned email. edit? aliases update?.
  def update?
    owner?
  end

  def destroy?
    owner?
  end

  def credential_registration_requirement(token:)
    unless user.is_a?(Client) && user.persisted? && record.is_a?(ClientEmail) &&
        record.user_id == user.id && token.is_a?(ClientToken) && token.persisted? &&
        token.user_id == user.id
      raise ArgumentError, "Contact registration requirement binding is invalid"
    end

    StepUpRequirement.new(
      step_up_required: true,
      scope: "settings_email",
      allowed_methods: %i(email_otp passkey totp),
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      session_binding: token.public_id,
      token_binding: token.public_id,
      ttl: 15.minutes,
      purpose: "step_up",
      audience: "step_up:app",
      require_session_binding: true,
      actor_ref: user.public_id,
      resource_ref: nil,
      tenant_ref: nil,
    )
  end
end
