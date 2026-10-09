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
      actor_ref: user.public_id, resource_ref: nil, tenant_ref: nil,
    )
  end

  def management_authorized?(token:, now:)
    requirement = management_requirement(token: token)
    device = token.device_session.reload
    user.login_allowed? && !token.restricted? && token.currently_usable?(now) && device.usable? &&
      device.current_refresh_token_id == token.id &&
      StepUpResolver.call(token: token, requirement: requirement, now: now).satisfied? &&
      current_management_credential?(token, now)
  end

  def management_credential(token:)
    credentials =
      case token.last_step_up_method
      when "passkey" then user.client_passkeys.active.where.not(uv_verified_at: nil)
      when "email_otp"
        user.client_emails.effective_binding.where(user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES)
      when "totp"
        user.client_totp_credentials.where(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
      else return nil
      end
    credentials.find_by(public_id: token.last_step_up_credential_ref)
  end

  private

  def current_management_credential?(token, now)
    credential = management_credential(token: token)
    return false unless credential

    credential.is_a?(ClientTotpCredential) ? credential.usable? : credential.accessible?(now)
  end
end
