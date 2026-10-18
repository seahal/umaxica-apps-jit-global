# typed: false
# frozen_string_literal: true

# Page and JSON shaping shared by the org Enforcement Case controllers (the Case resource and its
# approval, release, and appeal review sub-resources). It holds no authorization, Step-Up, or state
# transition; each controller declares those itself.
#
# Contract: the including controller also includes EnforcementCaseRealmResolvable and
# OrgAdministrationPage, and uses `with: EnforcementCasePolicy` for every rule it checks.
module OrgEnforcementCasePage
  extend ActiveSupport::Concern

  # Operator-selectable end reasons for a release. The others (expired, appeal_approved,
  # break_glass_released, verification_completed, superseded) are recorded only by their own paths.
  OPERATOR_RELEASE_REASONS = %w(revoked corrected).freeze

  private

  def enforcement_realm
    realm = params.fetch(:realm).to_s
    EnforcementCaseRealmResolvable::CASE_CLASS_BY_REALM.fetch(realm) do
      raise ActionController::RoutingError, "unknown realm"
    end
    realm
  end

  def enforcement_case_path_for(enforcement_case)
    case enforcement_case
    when AppEnforcementCase then base_org_support_app_enforcement_case_path(enforcement_case.public_id)
    when ComEnforcementCase then base_org_support_com_enforcement_case_path(enforcement_case.public_id)
    when OrgEnforcementCase then base_org_support_org_enforcement_case_path(enforcement_case.public_id)
    else raise ArgumentError, "unsupported enforcement case: #{enforcement_case.class.name}"
    end
  end

  def enforcement_cases_path_for(enforcement_case)
    case enforcement_case
    when AppEnforcementCase then base_org_support_app_enforcement_cases_path
    when ComEnforcementCase then base_org_support_com_enforcement_cases_path
    when OrgEnforcementCase then base_org_support_org_enforcement_cases_path
    else raise ArgumentError, "unsupported enforcement case: #{enforcement_case.class.name}"
    end
  end

  def new_enforcement_approval_path_for(enforcement_case)
    case enforcement_case
    when AppEnforcementCase then new_base_org_support_app_enforcement_case_approval_path(enforcement_case.public_id)
    when ComEnforcementCase then new_base_org_support_com_enforcement_case_approval_path(enforcement_case.public_id)
    else raise ArgumentError, "no approval screen for #{enforcement_case.class.name}"
    end
  end

  def new_enforcement_release_path_for(enforcement_case)
    case enforcement_case
    when AppEnforcementCase then new_base_org_support_app_enforcement_case_release_path(enforcement_case.public_id)
    when ComEnforcementCase then new_base_org_support_com_enforcement_case_release_path(enforcement_case.public_id)
    else raise ArgumentError, "no release screen for #{enforcement_case.class.name}"
    end
  end

  def new_enforcement_appeal_review_path_for(enforcement_case)
    case enforcement_case
    when AppEnforcementCase
      new_base_org_support_app_enforcement_case_appeal_review_path(enforcement_case.public_id)
    when ComEnforcementCase
      new_base_org_support_com_enforcement_case_appeal_review_path(enforcement_case.public_id)
    else raise ArgumentError, "no appeal review screen for #{enforcement_case.class.name}"
    end
  end

  def enforcement_case_json(enforcement_case)
    {
      public_id: enforcement_case.public_id,
      kind: enforcement_case.kind,
      state: enforcement_case.state,
      duration_mode: enforcement_case.duration_mode,
      visibility: enforcement_case.visibility,
      release_mode: enforcement_case.release_mode,
      effective_at: enforcement_case.effective_at,
      expires_at: enforcement_case.expires_at,
      ended_at: enforcement_case.ended_at,
      end_reason: enforcement_case.end_reason,
      reason_code: enforcement_case.reason_code,
      principal_public_id: enforcement_case.principal_public_id,
      applied_by_operator_public_id: enforcement_case.applied_by_operator_public_id,
      approved_by_operator_public_id: enforcement_case.approved_by_operator_public_id,
      requires_approval: enforcement_case.requires_approval?,
    }
  end

  def enforcement_case_fields(enforcement_case)
    effect = enforcement_case.principal_effect
    [
      { term: t("base.org.admin.fields.case_id"), description: enforcement_case.public_id },
      { term: t("base.org.admin.fields.principal"), description: enforcement_case.principal_public_id },
      { term: t("base.org.admin.fields.kind"), description: enforcement_case.kind },
      { term: t("base.org.admin.fields.state"), description: enforcement_case.state },
      { term: t("base.org.admin.fields.in_force"), description: enforcement_case.in_force?.to_s },
      { term: t("base.org.admin.fields.release_mode"), description: enforcement_case.release_mode },
      { term: t("base.org.admin.fields.reason_code"), description: enforcement_case.reason_code },
      { term: t("base.org.admin.fields.ticket_id"),
        description: enforcement_case.ticket_id || t("base.org.admin.values.none"), },
      { term: t("base.org.admin.fields.access_blocking"), description: (effect&.access_blocking? || false).to_s },
      { term: t("base.org.admin.fields.applied_by"), description: enforcement_case.applied_by_operator_public_id },
      { term: t("base.org.admin.fields.approved_by"),
        description: enforcement_case.approved_by_operator_public_id || t("base.org.admin.values.none"), },
      { term: t("base.org.admin.fields.effective_at"), description: admin_time(enforcement_case.effective_at) },
      { term: t("base.org.admin.fields.expires_at"), description: admin_time(enforcement_case.expires_at) },
      { term: t("base.org.admin.fields.ended_at"), description: admin_time(enforcement_case.ended_at) },
      { term: t("base.org.admin.fields.end_reason"),
        description: enforcement_case.end_reason || t("base.org.admin.values.none"), },
      { term: t("base.org.admin.fields.audited_at"), description: admin_time(enforcement_case.audited_at) },
    ]
  end

  def enforcement_show_props(enforcement_case)
    {
      title: t("base.org.admin.enforcement.show_title", public_id: enforcement_case.public_id),
      up_link: { label: t("base.org.admin.enforcement.title"), href: enforcement_cases_path_for(enforcement_case) },
      context: admin_context(realm: enforcement_realm),
      notices: enforcement_case_notices(enforcement_case),
      fields: enforcement_case_fields(enforcement_case),
      actions: enforcement_case_actions(enforcement_case),
      sections: [],
    }
  end

  # An active Case whose convergence columns are still null has committed its decision but not
  # finished its side effects or audit event; say so instead of presenting it as settled.
  def enforcement_case_notices(enforcement_case)
    return [] unless enforcement_case.state == "active"
    return [] if enforcement_case.audited_at.present?

    [{ tone: "warning", message: t("base.org.admin.enforcement.convergence_pending") }]
  end

  def enforcement_case_actions(enforcement_case)
    actions = []
    if enforcement_case.state == "pending_approval" &&
        allowed_to?(:approve?, enforcement_case, with: EnforcementCasePolicy)
      actions << { label: t("base.org.admin.enforcement.approve_action"),
                   href: new_enforcement_approval_path_for(enforcement_case), }
    end
    if enforcement_case.state == "active" && enforcement_case.ended_at.nil? &&
        allowed_to?(:release?, enforcement_case, with: EnforcementCasePolicy)
      actions << { label: t("base.org.admin.enforcement.release_action"),
                   href: new_enforcement_release_path_for(enforcement_case), }
    end
    if %w(submitted under_review).include?(enforcement_case.appeal&.state) &&
        allowed_to?(:review_appeal?, enforcement_case, with: EnforcementCasePolicy)
      actions << { label: t("base.org.admin.enforcement.appeal_review_action"),
                   href: new_enforcement_appeal_review_path_for(enforcement_case), }
    end
    actions
  end

  def enforcement_confirmation_props(enforcement_case, title:, effect:, action:, fields:, acknowledgement:,
                                     submit_label:, errors: {})
    {
      title: title,
      up_link: { label: enforcement_case.public_id, href: enforcement_case_path_for(enforcement_case) },
      context: admin_context(realm: enforcement_realm),
      target: enforcement_case_fields(enforcement_case),
      effect: effect,
      action: action,
      fields: fields,
      acknowledgement: acknowledgement,
      submit_label: submit_label,
      errors: errors,
    }
  end
end
