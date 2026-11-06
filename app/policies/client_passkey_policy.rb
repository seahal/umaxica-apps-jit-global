# typed: false
# frozen_string_literal: true

class ClientPasskeyPolicy < ApplicationPolicy
  public

  def index?
    user.present?
  end

  def show?
    owner?
  end

  def create?
    user.present?
  end

  def new?
    create?
  end

  def update?
    owner?
  end

  def edit?
    update?
  end

  def destroy?
    owner?
  end

  relation_scope do |relation|
    return relation.none unless user

    relation.where(user_id: user.id)
  end
  def management_requirement(token:)
    unless user.is_a?(Client) && user.persisted? && token.is_a?(ClientToken) && token.persisted? &&
        token.user_id == user.id
      raise ArgumentError, "Passkey management requires a bound app actor and session"
    end

    StepUpRequirement.new(
      step_up_required: true, scope: "settings_passkey", allowed_methods: %i(email_otp passkey totp),
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, session_binding: token.public_id, token_binding: token.public_id,
      ttl: 15.minutes, purpose: "step_up", audience: "step_up:app", require_session_binding: true,
      actor_ref: user.public_id, resource_ref: (record.is_a?(ClientPasskey) ? record.public_id : nil), tenant_ref: nil,
    )
  end

  def management_authorized?(token:, now:)
    return false unless user.is_a?(Client) && token.is_a?(ClientToken) && token.user_id == user.id

    device = ClientDeviceSession.find_by(id: token.device_session_id, user_id: user.id)
    user.login_allowed? && token.active_status?(now) && device&.usable? &&
      device.current_refresh_token_id == token.id
  end
end
