# typed: false
# frozen_string_literal: true

# Authorization for the com (visitor) passkey listing.
#
# `Sign::Com::Settings::PasskeysController` scopes every query to
# `current_visitor.visitor_passkeys`. `index?`/`create?` gate the actor *type*; the per-record
# rules require ownership (record.visitor_id == visitor.id). Mirrors ClientPasskeyPolicy.
class VisitorPasskeyPolicy < ApplicationPolicy
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

    relation.where(visitor_id: user.id)
  end
  def management_requirement(token:)
    unless user.is_a?(Visitor) && user.persisted? && token.is_a?(VisitorToken) && token.persisted? &&
        token.visitor_id == user.id
      raise ArgumentError, "Passkey management requires a bound com actor and session"
    end

    StepUpRequirement.new(
      step_up_required: true, scope: "settings_passkey", allowed_methods: %i(email_otp passkey),
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, session_binding: token.public_id, token_binding: token.public_id,
      ttl: 15.minutes, purpose: "step_up", audience: "step_up:com", require_session_binding: true,
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
      when "passkey" then user.visitor_passkeys.active.where.not(uv_verified_at: nil)
      when "email_otp"
        user.visitor_emails.effective_binding.where(
          visitor_email_status_id: AuthMethodGuard::VISITOR_VERIFIED_EMAIL_STATUSES,
        )
      else return nil
      end
    credentials.find_by(public_id: token.last_step_up_credential_ref)
  end

  private

  def current_management_credential?(token, now)
    credential = management_credential(token: token)
    return false unless credential

    credential.accessible?(now)
  end
end
