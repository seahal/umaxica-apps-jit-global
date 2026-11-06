# frozen_string_literal: true

require "test_helper"

class RpBaseOrgStepUpAuditOutboxTest < ActiveSupport::TestCase
  test "the database accepts the exact payload keys for every event type" do
    payloads = [
      ["step_up.requested", { rp_state_ref: "rp-state", return_target_kind: "relative" }, "requested"],
      ["step_up.committed",
       { op_context_ref: "op-context", grant_ref: "grant", verified_method: "passkey", auth_time: 1 }, "completed",],
      ["step_up.installed", { rp_state_ref: "rp-state", grant_ref: "grant", installed_generation: 1 }, "completed"],
      ["step_up.cancelled", { op_context_ref: "op-context" }, "user_cancelled"],
      ["step_up.expired", { rp_state_ref: "rp-state" }, "expired"],
      ["step_up.failed", { op_context_ref: "op-context", failure_code: "policy_refused" }, "policy_refused"],
      ["step_up.refused", { rp_state_ref: "rp-state", failure_code: "session_invalid" }, "session_invalid"],
      ["step_up.indeterminate", { rp_state_ref: "rp-state", failure_code: "exchange_timeout" }, "exchange_timeout"],
      ["step_up.attempt_rejected", { context_ref: "context", rejection_code: "foreign_browser" }, "foreign_browser"],
    ]

    payloads.each_with_index do |(event_type, payload, reason_code), index|
      RpBaseOrgStepUpAuditOutbox.create!(
        event_uuid: "00000000-0000-4000-8000-#{format("%012d", index + 1)}",
        event_type: event_type,
        realm: "ORG",
        client_id: "base-org-ww",
        subject_ref: "subject-ref",
        context_ref: "123456789abcdefghijk",
        reason_code: reason_code,
        payload: payload,
        occurred_at: Time.utc(2026, 11, 3, 12),
        delivery_state: RpBaseOrgStepUpAuditOutboxDeliveryState.find(RpBaseOrgStepUpAuditOutboxDeliveryState::PENDING),
      )
    end

    assert_equal payloads.length, RpBaseOrgStepUpAuditOutbox.count
    assert_raises(ActiveRecord::RecordNotUnique) do
      RpBaseOrgStepUpAuditOutbox.create!(
        event_uuid: "00000000-0000-4000-8000-000000000001",
        event_type: "step_up.requested",
        realm: "ORG",
        client_id: "base-org-ww",
        subject_ref: "subject-ref",
        context_ref: "223456789abcdefghijk",
        reason_code: "requested",
        payload: { rp_state_ref: "another-state", return_target_kind: "relative" },
        occurred_at: Time.utc(2026, 11, 3, 12),
        delivery_state: RpBaseOrgStepUpAuditOutboxDeliveryState.find(RpBaseOrgStepUpAuditOutboxDeliveryState::PENDING),
      )
    end
  end

  test "the database rejects an unexpected payload key" do
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        RpBaseOrgStepUpAuditOutbox.create!(
          event_uuid: "00000000-0000-4000-8000-000000000101",
          event_type: "step_up.requested",
          realm: "ORG",
          client_id: "base-org-ww",
          subject_ref: "subject-ref",
          context_ref: "123456789abcdefghijk",
          reason_code: "requested",
          payload: { rp_state_ref: "rp-state", return_target_kind: "relative", extra: "value" },
          occurred_at: Time.utc(2026, 11, 3, 12),
          delivery_state: RpBaseOrgStepUpAuditOutboxDeliveryState.find(RpBaseOrgStepUpAuditOutboxDeliveryState::PENDING),
        )
      end

    assert_includes error.message, "chk_rp_step_up_audit_payload"
  end

  test "the database rejects unknown reason and event-specific payload codes" do
    invalid_outbox = RpBaseOrgStepUpAuditOutbox.new(reason_code: "future_reason")

    assert_not invalid_outbox.valid?
    assert_includes invalid_outbox.errors.attribute_names, :reason_code

    reason_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        RpBaseOrgStepUpAuditOutbox.transaction(requires_new: true) do
          RpBaseOrgStepUpAuditOutbox.insert!(
            {
              event_uuid: "00000000-0000-4000-8000-000000000111",
              event_type: "step_up.requested",
              realm: "ORG",
              client_id: "base-org-ww",
              subject_ref: "subject-ref",
              context_ref: "123456789abcdefghijk",
              reason_code: "future_reason",
              payload: { rp_state_ref: "rp-state", return_target_kind: "relative" },
              occurred_at: Time.utc(2026, 11, 3, 12),
              delivery_state_id: RpBaseOrgStepUpAuditOutboxDeliveryState::PENDING,
              created_at: Time.utc(2026, 11, 3, 12),
              updated_at: Time.utc(2026, 11, 3, 12),
            },
          )
        end
      end
    assert_includes reason_error.message, "chk_rp_step_up_audit_reason_codes"

    payload_error =
      assert_raises(ActiveRecord::StatementInvalid) do
        RpBaseOrgStepUpAuditOutbox.transaction(requires_new: true) do
          RpBaseOrgStepUpAuditOutbox.insert!(
            {
              event_uuid: "00000000-0000-4000-8000-000000000112",
              event_type: "step_up.failed",
              realm: "ORG",
              client_id: "base-org-ww",
              subject_ref: "subject-ref",
              context_ref: "123456789abcdefghijk",
              reason_code: "policy_refused",
              payload: { op_context_ref: "op-context", failure_code: "session_invalid" },
              occurred_at: Time.utc(2026, 11, 3, 12),
              delivery_state_id: RpBaseOrgStepUpAuditOutboxDeliveryState::PENDING,
              created_at: Time.utc(2026, 11, 3, 12),
              updated_at: Time.utc(2026, 11, 3, 12),
            },
          )
        end
      end
    assert_includes payload_error.message, "chk_rp_step_up_audit_payload_codes"
  end

  test "rejected attempts are unique by realm client context and reason" do
    attributes = {
      realm: "ORG",
      client_id: "base-org-ww",
      subject_ref: "subject-ref",
      context_ref: "123456789abcdefghijk",
      reason_code: "foreign_browser",
      payload: { context_ref: "context", rejection_code: "foreign_browser" },
      occurred_at: Time.utc(2026, 11, 3, 12),
      delivery_state: RpBaseOrgStepUpAuditOutboxDeliveryState.find(RpBaseOrgStepUpAuditOutboxDeliveryState::PENDING),
    }
    RpBaseOrgStepUpAuditOutbox.create!(
      attributes.merge(
        event_uuid: "00000000-0000-4000-8000-000000000102", event_type: "step_up.attempt_rejected",
      ),
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      RpBaseOrgStepUpAuditOutbox.create!(
        attributes.merge(
          event_uuid: "00000000-0000-4000-8000-000000000103", event_type: "step_up.attempt_rejected",
        ),
      )
    end
  end
end
