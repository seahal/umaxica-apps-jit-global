# typed: false
# frozen_string_literal: true

# Authorization for the org (operator) passkey listing.
#
# `Sign::Org::Settings::PasskeysController` scopes every query to
# `current_operator.staff_passkeys`. `index?`/`create?` gate the actor *type*; the per-record
# rules require ownership (record.staff_id == operator.id). Mirrors ClientPasskeyPolicy.
class OperatorPasskeyPolicy < ApplicationPolicy
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

    relation.where(staff_id: user.id)
  end
  def management_requirement(token:)
    unless user.is_a?(Operator) && user.persisted? && token.is_a?(OperatorToken) && token.persisted? &&
        token.staff_id == user.id
      raise ArgumentError, "Passkey management requires a bound org actor and session"
    end

    StepUpRequirement.new(
      step_up_required: true, scope: "settings_passkey", allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, session_binding: token.public_id, token_binding: token.public_id,
      ttl: 15.minutes, purpose: "step_up", audience: "step_up:org", require_session_binding: true,
      actor_ref: user.public_id, resource_ref: nil, tenant_ref: nil,
    )
  end

  def management_authorized?(token:, now:)
    requirement = management_requirement(token: token)
    device = token.device_session_record!
    device.reload
    user.login_allowed? && token.active_status?(now) && device.usable? &&
      device.current_refresh_token_id == token.id &&
      StepUpResolver.call(token: token, requirement: requirement, now: now).satisfied? &&
      current_management_credential?(token, now)
  end

  def management_credential(token:)
    return unless token.last_step_up_method == "passkey"

    OperatorPasskey.active.find_by(staff_id: user.id, external_id: token.last_step_up_credential_ref)
  end

  private

  def current_management_credential?(token, _now)
    management_credential(token: token).present?
  end
end
