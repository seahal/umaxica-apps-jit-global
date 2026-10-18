# typed: false
# frozen_string_literal: true

# Authorization for the org (operator) telephone listing.
#
# `Sign::Org::Settings::TelephonesController` and its registration subcontroller scope every
# query to `current_operator.staff_telephones`, so row-level ownership is enforced by those queries.
# `index?`/`create?` gate the actor *type*; per-record write rules require ownership
# (record.staff_id == operator.id). Other defaults stay deny-all (allowlist).
class OperatorTelephonePolicy < ApplicationPolicy
  public

  def credential_registration_requirement(token:)
    unless user.is_a?(Operator) && user.persisted? && record.is_a?(OperatorTelephone) && record.staff_id == user.id &&
        token.is_a?(OperatorToken) && token.persisted? && token.staff_id == user.id
      raise ArgumentError, "ORG Telephone registration requires its Operator candidate and Root"
    end

    StepUpRequirement.new(
      scope: "settings_telephone", allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:org",
      step_up_required: true, phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: user.public_id,
      resource_ref: nil, tenant_ref: nil, session_binding: token.public_id, token_binding: token.public_id,
      require_session_binding: true,
    )
  end

  def index?
    user.is_a?(Operator)
  end

  # Registration (new/create) is a fresh, unsaved record; gate by actor type. new? aliases create?.
  def create?
    user.is_a?(Operator)
  end

  # Per-record management of an owned telephone. edit? aliases update?.
  def update?
    owner?
  end

  def destroy?
    owner?
  end
end
