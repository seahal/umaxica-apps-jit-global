# typed: false
# frozen_string_literal: true

# adr/operator-capability-authorization.md, Support: input validation and page shaping shared by
# the per-realm session revocation controllers (Support::Clients::RevocationsController and
# Support::Visitors::RevocationsController).
#
# It deliberately does not choose the target class, authorize, require Step-Up, or call the
# revocation: each concrete controller states those itself. Contract: the including controller also
# includes OrgAdministrationPage and OrgAdministrativeAudit, and provides `current_operator`.
module OrgSupportSessionRevocationPage
  extend ActiveSupport::Concern

  AUDIT_ACTION = "support.session.revoked"
  TICKET_ID_FORMAT = /\A[A-Za-z0-9][A-Za-z0-9._-]{0,63}\z/

  class InvalidRevocationInput < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super("invalid revocation input")
    end
  end

  private

  # Returns the validated reason code, ticket id (or nil), and operation id. Free-text notes are not
  # accepted: audit reasons are fixed codes, and a ticket id is a bounded identifier.
  def revocation_input!
    errors = {}
    reason_code = params[:reason_code]
    unless reason_code.is_a?(String) && AdministrativeAccessLockable::ADMIN_LOCK_REASON_CODES.include?(reason_code)
      errors[:reason_code] = t("base.org.admin.errors.reason_code")
    end

    ticket_id = params[:ticket_id]
    ticket_id = nil if ticket_id == ""
    unless ticket_id.nil? || (ticket_id.is_a?(String) && TICKET_ID_FORMAT.match?(ticket_id))
      errors[:ticket_id] = t("base.org.admin.errors.ticket_id")
    end

    operation_id = params[:operation_id]
    unless operation_id.is_a?(String) && OrgAdministrativeAudit::OPERATION_ID_FORMAT.match?(operation_id)
      errors[:operation_id] = t("base.org.admin.errors.operation_id")
    end
    raise InvalidRevocationInput, errors if errors.any?

    [reason_code, ticket_id, operation_id]
  end

  def revocation_audit_metadata(target:, realm:, ticket_id:)
    { realm: realm, subject_public_id: target.public_id, ticket_id: ticket_id }
  end

  def revocation_audit_changeset(target)
    {
      before: {
        access_state: target.access_state,
        active_session_count: AuthenticationSessionRevoker.tokens_for(target).not_revoked.count,
      },
    }
  end

  def revocation_confirmation_props(target:, realm:, action_path:, up_link:, errors: {}, values: {})
    {
      title: t("base.org.admin.revocations.new_title"),
      up_link: up_link,
      context: admin_context(realm: realm),
      target: [
        { term: t("base.org.admin.fields.public_id"), description: target.public_id },
        { term: t("base.org.admin.fields.access_state"), description: target.access_state },
        {
          term: t("base.org.admin.fields.active_sessions"),
          description: AuthenticationSessionRevoker.tokens_for(target).not_revoked.count.to_s,
        },
      ],
      effect: t("base.org.admin.revocations.effect"),
      action: action_path,
      fields: [
        {
          kind: "select",
          name: "reason_code",
          label: t("base.org.admin.fields.reason_code"),
          value: values.fetch(:reason_code, ""),
          options: AdministrativeAccessLockable::ADMIN_LOCK_REASON_CODES.map { |code| { value: code, label: code } },
        },
        {
          kind: "text",
          name: "ticket_id",
          label: t("base.org.admin.fields.ticket_id"),
          value: values.fetch(:ticket_id, ""),
          maxlength: 64,
          required: false,
        },
        # A fresh id per rendered confirmation: the same screen resubmitted is one operation.
        { kind: "hidden", name: "operation_id", value: values.fetch(:operation_id, admin_operation_id) },
      ],
      acknowledgement: t("base.org.admin.revocations.acknowledgement"),
      submit_label: t("base.org.admin.revocations.submit"),
      errors: errors,
    }
  end

  # The recorded operation for this target, or 404. An id recorded for another target, another
  # action, or a different subject class is not this revocation.
  def recorded_revocation!(target)
    chronicle = Chronicle.find_by(
      event_uuid: params.expect(:id),
      action: AUDIT_ACTION,
      subject_type: target.class.name,
      subject_id: target.id,
    )
    raise ActiveRecord::RecordNotFound, "revocation not found" if chronicle.nil?

    chronicle
  end

  def revocation_result_props(chronicle:, target:, realm:, up_link:)
    actor = Operator.find_by(id: chronicle.actor_id) if chronicle.actor_type == "Operator"
    {
      title: t("base.org.admin.revocations.show_title"),
      up_link: up_link,
      context: admin_context(realm: realm),
      notices: revocation_result_notices(chronicle),
      fields: [
        { term: t("base.org.admin.fields.operation_id"), description: chronicle.event_uuid },
        { term: t("base.org.admin.fields.result"),
          description: revocation_result_label(chronicle), },
        { term: t("base.org.admin.fields.target"), description: target.public_id },
        { term: t("base.org.admin.fields.performed_by"),
          description: actor&.public_id || t("base.org.admin.values.none"), },
        { term: t("base.org.admin.fields.reason_code"), description: chronicle.reason.to_s },
        { term: t("base.org.admin.fields.ticket_id"),
          description: chronicle.metadata["ticket_id"] || t("base.org.admin.values.none"), },
        { term: t("base.org.admin.fields.occurred_at"), description: admin_time(chronicle.occurred_at) },
        { term: t("base.org.admin.fields.revoked_count"), description: chronicle.changeset["revoked_count"].to_s },
      ],
      actions: [],
      sections: [],
    }
  end

  # Maps the Chronicle result vocabulary onto what the operator is told. Anything that is not a
  # recorded success is reported as incomplete or failed, never as done.
  def revocation_result_key(chronicle)
    case chronicle.result
    when "succeeded" then "succeeded"
    when "failed" then "failed"
    when "intent" then "incomplete"
    else "recovery_required"
    end
  end

  def revocation_result_label(chronicle)
    case revocation_result_key(chronicle)
    when "succeeded" then t("base.org.admin.results.succeeded")
    when "failed" then t("base.org.admin.results.failed")
    when "incomplete" then t("base.org.admin.results.incomplete")
    else t("base.org.admin.results.recovery_required")
    end
  end

  def revocation_result_notices(chronicle)
    case revocation_result_key(chronicle)
    when "succeeded" then []
    when "failed" then [{ tone: "danger", message: t("base.org.admin.results.failed_notice") }]
    else [{ tone: "warning", message: t("base.org.admin.results.incomplete_notice") }]
    end
  end
end
