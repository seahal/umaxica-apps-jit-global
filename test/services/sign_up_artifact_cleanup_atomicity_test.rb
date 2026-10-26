# frozen_string_literal: true

require "test_helper"

class SignUpArtifactCleanupAtomicityTest < ActiveSupport::TestCase
  test "APP actor retention failure rolls back contact and Passkey retirement and remains retryable" do
    contact_time = Time.current.change(usec: 0)
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP, created_at: contact_time + 2.hours,
    )
    contact = ClientTelephone.create!(
      user: actor, raw_number: "+12345678901", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, created_at: contact_time,
    )
    passkey = actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "pending-test-key")
    cycle = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: actor.id, pending_contact_type: "telephone", pending_contact_id: contact.id,
      pending_passkey_registration_id: passkey.id, entry_method: "telephone",
      status_id: ClientSignUpFlowStatus::CANCELLED, step: "cancelled",
      nonce_digest: ClientSignUpFlow.digest_nonce("cleanup-browser"),
      issued_at: contact_time, expires_at: contact_time + 15.minutes,
      cleanup_status_id: ClientSignUpFlowCleanupStatus::PENDING,
    )
    audit_count = ClientPasskeyAuditOutbox.count

    # The real retention invariant refuses an actor created after the proposed purge deadline.
    SignUpArtifactCleanup.call(cycle: cycle, now: contact_time + 10.minutes)

    assert_equal ClientSignUpFlowCleanupStatus::FAILED, cycle.reload.cleanup_status_id
    assert_equal ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, contact.reload.user_telephone_status_id
    assert ClientPasskey.exists?(passkey.id)
    assert_equal audit_count, ClientPasskeyAuditOutbox.count
    assert_equal Float::INFINITY, actor.reload.discard_at

    SignUpArtifactCleanup.call(cycle: cycle, now: contact_time + 3.hours)

    assert_equal ClientSignUpFlowCleanupStatus::COMPLETED, cycle.reload.cleanup_status_id
    assert_equal ClientTelephoneStatus::DELETED, contact.reload.user_telephone_status_id
    assert_not ClientPasskey.exists?(passkey.id)
    assert_equal audit_count + 1, ClientPasskeyAuditOutbox.count
    assert_equal contact_time + 3.hours, actor.reload.discard_at
  end

  test "COM actor retention failure rolls back contact and Passkey retirement and remains retryable" do
    contact_time = Time.current.change(usec: 0)
    actor = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: VisitorStatus::UNVERIFIED_WITH_SIGN_UP, created_at: contact_time + 2.hours,
    )
    contact = VisitorTelephone.create!(
      visitor: actor, raw_number: "+12345678902", confirm_policy: true,
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, created_at: contact_time,
    )
    passkey = actor.visitor_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "pending-test-key")
    cycle = VisitorSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(VisitorSignUpFlow),
      principal_id: actor.id, pending_contact_type: "telephone", pending_contact_id: contact.id,
      pending_passkey_registration_id: passkey.id, entry_method: "telephone",
      status_id: VisitorSignUpFlowStatus::CANCELLED, step: "cancelled",
      nonce_digest: VisitorSignUpFlow.digest_nonce("cleanup-browser"),
      issued_at: contact_time, expires_at: contact_time + 15.minutes,
      cleanup_status_id: VisitorSignUpFlowCleanupStatus::PENDING,
    )
    audit_count = VisitorPasskeyAuditOutbox.count

    SignUpArtifactCleanup.call(cycle: cycle, now: contact_time + 10.minutes)

    assert_equal VisitorSignUpFlowCleanupStatus::FAILED, cycle.reload.cleanup_status_id
    assert_equal VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, contact.reload.visitor_telephone_status_id
    assert VisitorPasskey.exists?(passkey.id)
    assert_equal audit_count, VisitorPasskeyAuditOutbox.count
    assert_equal Float::INFINITY, actor.reload.discard_at

    SignUpArtifactCleanup.call(cycle: cycle, now: contact_time + 3.hours)

    assert_equal VisitorSignUpFlowCleanupStatus::COMPLETED, cycle.reload.cleanup_status_id
    assert_equal VisitorTelephoneStatus::DELETED, contact.reload.visitor_telephone_status_id
    assert_not VisitorPasskey.exists?(passkey.id)
    assert_equal audit_count + 1, VisitorPasskeyAuditOutbox.count
    assert_equal contact_time + 3.hours, actor.reload.discard_at
  end

  test "APP active and verified registrations survive terminal flow cleanup" do
    [ClientStatus::ACTIVE, ClientStatus::VERIFIED_WITH_SIGN_UP].each do |status|
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: status)
      contact = ClientTelephone.create!(
        user: actor, raw_number: "+12345678903", confirm_policy: true, confirm_using_mfa: true,
        user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
      )
      cycle = ClientSignUpFlow.create!(
        auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
        principal_id: actor.id, pending_contact_type: "telephone", pending_contact_id: contact.id,
        entry_method: "telephone", status_id: ClientSignUpFlowStatus::CANCELLED, step: "cancelled",
        nonce_digest: ClientSignUpFlow.digest_nonce("cleanup-browser"),
        issued_at: Time.current, expires_at: 15.minutes.from_now,
      )

      SignUpArtifactCleanup.call(cycle: cycle)

      assert_equal Float::INFINITY, actor.reload.discard_at
      assert_equal status, actor.status_id
      assert_equal ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, contact.reload.user_telephone_status_id
      assert_equal Float::INFINITY, contact.discard_at
    end
  end

  test "COM verified contact survives terminal flow cleanup" do
    actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::UNVERIFIED_WITH_SIGN_UP)
    contact = VisitorTelephone.create!(
      visitor: actor, raw_number: "+12345678904", confirm_policy: true,
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    cycle = VisitorSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(VisitorSignUpFlow),
      principal_id: actor.id, pending_contact_type: "telephone", pending_contact_id: contact.id,
      entry_method: "telephone", status_id: VisitorSignUpFlowStatus::CANCELLED, step: "cancelled",
      nonce_digest: VisitorSignUpFlow.digest_nonce("cleanup-browser"),
      issued_at: Time.current, expires_at: 15.minutes.from_now,
    )

    SignUpArtifactCleanup.call(cycle: cycle)

    assert_equal Float::INFINITY, actor.reload.discard_at
    assert_equal VisitorTelephoneStatus::VERIFIED, contact.reload.visitor_telephone_status_id
    assert_equal Float::INFINITY, contact.discard_at
  end

  test "APP cleanup cannot retire artifacts of an in-progress flow" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    contact = ClientTelephone.create!(
      user: actor, raw_number: "+12345678905", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    cycle = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: actor.id, pending_contact_type: "telephone", pending_contact_id: contact.id,
      entry_method: "telephone", status_id: ClientSignUpFlowStatus::CONTACT_PENDING, step: "contact",
      nonce_digest: ClientSignUpFlow.digest_nonce("cleanup-browser"),
      issued_at: Time.current, expires_at: 15.minutes.from_now,
    )
    original_cleanup_status = cycle.cleanup_status_id

    SignUpArtifactCleanup.call(cycle: cycle)

    assert_equal original_cleanup_status, cycle.reload.cleanup_status_id
    assert_equal Float::INFINITY, actor.reload.discard_at
    assert_equal ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, contact.reload.user_telephone_status_id
    assert_equal Float::INFINITY, contact.discard_at
  end

  test "COM cleanup cannot retire artifacts of an in-progress flow" do
    actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::UNVERIFIED_WITH_SIGN_UP)
    contact = VisitorTelephone.create!(
      visitor: actor, raw_number: "+12345678906", confirm_policy: true,
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    cycle = VisitorSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(VisitorSignUpFlow),
      principal_id: actor.id, pending_contact_type: "telephone", pending_contact_id: contact.id,
      entry_method: "telephone", status_id: VisitorSignUpFlowStatus::CONTACT_PENDING, step: "contact",
      nonce_digest: VisitorSignUpFlow.digest_nonce("cleanup-browser"),
      issued_at: Time.current, expires_at: 15.minutes.from_now,
    )
    original_cleanup_status = cycle.cleanup_status_id

    SignUpArtifactCleanup.call(cycle: cycle)

    assert_equal original_cleanup_status, cycle.reload.cleanup_status_id
    assert_equal Float::INFINITY, actor.reload.discard_at
    assert_equal VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, contact.reload.visitor_telephone_status_id
    assert_equal Float::INFINITY, contact.discard_at
  end
end
