# frozen_string_literal: true

require "test_helper"

class RpBaseOrgStepUpAuditOutboxAttemptTest < ActiveSupport::TestCase
  test "only one delivered attempt can acknowledge an outbox row" do
    outbox = RpBaseOrgStepUpAuditOutbox.create!(
      event_uuid: "00000000-0000-4000-8000-000000000201",
      event_type: "step_up.requested",
      realm: "ORG",
      client_id: "base-org-ww",
      subject_ref: "subject-ref",
      context_ref: "123456789abcdefghijk",
      reason_code: "requested",
      payload: { rp_state_ref: "rp-state", return_target_kind: "relative" },
      occurred_at: Time.utc(2026, 11, 3, 12),
      delivery_state: RpBaseOrgStepUpAuditOutboxDeliveryState.find(RpBaseOrgStepUpAuditOutboxDeliveryState::PENDING),
    )
    RpBaseOrgStepUpAuditOutboxAttempt.create!(
      outbox: outbox, attempt_number: 2, attempted_at: Time.utc(2026, 11, 3, 12), outcome: "delivered",
      failure_code: "none",
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      RpBaseOrgStepUpAuditOutboxAttempt.create!(
        outbox: outbox, attempt_number: 3, attempted_at: Time.utc(2026, 11, 3, 12), outcome: "delivered",
        failure_code: "none",
      )
    end
  end

  test "attempt numbers must be greater than zero" do
    outbox = RpBaseOrgStepUpAuditOutbox.create!(
      event_uuid: "00000000-0000-4000-8000-000000000202",
      event_type: "step_up.requested",
      realm: "ORG",
      client_id: "base-org-ww",
      subject_ref: "subject-ref",
      context_ref: "123456789abcdefghijk",
      reason_code: "requested",
      payload: { rp_state_ref: "rp-state", return_target_kind: "relative" },
      occurred_at: Time.utc(2026, 11, 3, 12),
      delivery_state: RpBaseOrgStepUpAuditOutboxDeliveryState.find(RpBaseOrgStepUpAuditOutboxDeliveryState::PENDING),
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      RpBaseOrgStepUpAuditOutboxAttempt.create!(
        outbox: outbox, attempt_number: 0, attempted_at: Time.utc(2026, 11, 3, 12), outcome: "delivered",
        failure_code: "none",
      )
    end
  end

  test "the database enforces delivery failure codes and delivered none semantics" do
    outbox = RpBaseOrgStepUpAuditOutbox.create!(
      event_uuid: "00000000-0000-4000-8000-000000000203",
      event_type: "step_up.requested",
      realm: "ORG",
      client_id: "base-org-ww",
      subject_ref: "subject-ref",
      context_ref: "123456789abcdefghijk",
      reason_code: "requested",
      payload: { rp_state_ref: "rp-state", return_target_kind: "relative" },
      occurred_at: Time.utc(2026, 11, 3, 12),
      delivery_state: RpBaseOrgStepUpAuditOutboxDeliveryState.find(RpBaseOrgStepUpAuditOutboxDeliveryState::PENDING),
    )

    invalid_failure = RpBaseOrgStepUpAuditOutboxAttempt.new(outbox: outbox, outcome: "failed", failure_code: "unknown")

    assert_not invalid_failure.valid?
    assert_includes invalid_failure.errors.attribute_names, :failure_code

    assert_raises(ActiveRecord::StatementInvalid) do
      RpBaseOrgStepUpAuditOutboxAttempt.transaction(requires_new: true) do
        RpBaseOrgStepUpAuditOutboxAttempt.insert!(
          {
            outbox_id: outbox.id,
            attempt_number: 3,
            attempted_at: Time.utc(2026, 11, 3, 12),
            outcome: "failed",
            failure_code: "unknown",
          },
        )
      end
    end

    delivered_failure = RpBaseOrgStepUpAuditOutboxAttempt.new(
      outbox: outbox, outcome: "delivered", failure_code: "delivery_failed",
    )

    assert_not delivered_failure.valid?
    assert_includes delivered_failure.errors.attribute_names, :failure_code

    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        RpBaseOrgStepUpAuditOutboxAttempt.transaction(requires_new: true) do
          RpBaseOrgStepUpAuditOutboxAttempt.insert!(
            {
              outbox_id: outbox.id,
              attempt_number: 4,
              attempted_at: Time.utc(2026, 11, 3, 12),
              outcome: "delivered",
              failure_code: "delivery_failed",
            },
          )
        end
      end
    assert_includes error.message, "chk_rp_step_up_delivered_failure_none"
  end
end
