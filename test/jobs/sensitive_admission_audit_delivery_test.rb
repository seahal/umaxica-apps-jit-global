# frozen_string_literal: true

require "test_helper"

class SensitiveAdmissionAuditDeliveryTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "realm scoped closure accounting reaches Chronicle once without secrets" do
    references = []
    events = []
    [
      [ClientSensitiveAdmission, ClientSensitiveAdmissionAuditOutbox, ClientSensitiveAdmissionAuditAttempt, "app",
       "user_cancelled", "cancelled", "failed",],
      [ClientSensitiveAdmission, ClientSensitiveAdmissionAuditOutbox, ClientSensitiveAdmissionAuditAttempt, "app",
       "expired", "cancelled", "failed",],
      [ClientSensitiveAdmission, ClientSensitiveAdmissionAuditOutbox, ClientSensitiveAdmissionAuditAttempt, "app",
       "completed", "redeemed", "succeeded",],
      [OperatorSensitiveAdmission, OperatorSensitiveAdmissionAuditOutbox, OperatorSensitiveAdmissionAuditAttempt,
       "org", "expired", "cancelled", "failed",],
    ].each do |admissions, outboxes, attempts, realm, reason, status, result|
      now = admissions.database_now
      admission = admissions.create!(
        public_ref: PublicId.generate, secret_digest: SecureRandom.hex(32), realm: realm,
        client_id: "base-#{realm}-ww", actor_subject: "subject", grant_sid: "grant", rp_session_ref: "session",
        browser_binding_digest: SecureRandom.hex(32), purpose: "passkey_registration", provider: "none",
        event_jti: SecureRandom.uuid, event_auth_time: now.to_i, issued_at: now, expires_at: now + 1.minute,
        status: status,
      )
      references << [admissions, admission.id]
      event = nil
      admissions.transaction do
        event = SensitiveAdmissionAccountingWriter.call!(admission: admission, reason_code: reason)
      end
      events << [outboxes, attempts, event.id, event.event_uuid]
      assert_raises(ArgumentError) do
        admissions.transaction do
          SensitiveAdmissionAccountingWriter.call!(admission: admission, reason_code: reason)
        end
      end
      StepUpAuditDeliveryJob.perform_now(source_key: "o9_#{realm}")
      StepUpAuditDeliveryJob.perform_now(source_key: "o9_#{realm}")

      assert_equal 1, Chronicle.where(event_uuid: event.event_uuid).count
      assert_equal 1, attempts.where(outbox_id: event.id, outcome: "delivered").count
      chronicle = Chronicle.find_by!(event_uuid: event.event_uuid)

      assert_equal "sensitive_admission.closed", chronicle.action
      assert_equal result, chronicle.result
      assert_equal({ "admission_ref" => admission.public_ref }, event.reload.payload)
    end
  ensure
    events&.each do |outboxes, attempts, id, uuid|
      attempts.where(outbox_id: id).delete_all
      outboxes.where(id: id).delete_all
      Chronicle.where(event_uuid: uuid).delete_all
    end
    references&.each { |admissions, id| admissions.where(id: id).delete_all }
  end
end
