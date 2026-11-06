# frozen_string_literal: true

require "test_helper"

class PreferenceLifecycleJobTest < ActiveJob::TestCase
  teardown { Flipper.disable(RetentionPurgeJob::FEATURE_NAME) }

  test "retention suspension prevents preference collection" do
    preference = create_preference(ComPreference.database_now - 31.days)
    Flipper.enable(RetentionPurgeJob::FEATURE_NAME)

    assert_equal 0, PreferenceLifecycleJob.perform_now
    assert_predicate ComPreference.where(id: preference.id), :exists?
  end

  test "collects app preferences at and after the 30-day retention boundary" do
    now = AppPreference.database_now.change(usec: 0)
    AppPreferenceStatus.ensure_defaults!
    AppPreferenceThemeOption.ensure_defaults!
    before = AppPreference.create!(
      status_id: AppPreference::ACTIVE_STATUS_ID,
      jti: SecureRandom.uuid,
      last_issued_at: now - 430.days + Rational(1, 1_000_000),
      last_issued_expires_at: now - 30.days + Rational(1, 1_000_000),
    )
    at = AppPreference.create!(
      status_id: AppPreference::ACTIVE_STATUS_ID,
      jti: SecureRandom.uuid,
      last_issued_at: now - 430.days,
      last_issued_expires_at: now - 30.days,
    )
    after = AppPreference.create!(
      status_id: AppPreference::RETIRED_STATUS_ID,
      jti: SecureRandom.uuid,
      last_issued_at: now - 430.days - Rational(1, 1_000_000),
      last_issued_expires_at: now - 30.days - Rational(1, 1_000_000),
    )
    child = AppPreferenceTheme.create!(preference_id: after.id, option_id: AppPreferenceThemeOption::DARK)

    AppPreference.stub(:database_now, now) do
      assert_operator PreferenceLifecycleJob.perform_now, :>=, 2
    end

    assert_predicate AppPreference.where(id: before.id), :exists?
    assert_not AppPreference.exists?(at.id)
    assert_not AppPreference.exists?(after.id)
    assert_not AppPreferenceTheme.exists?(child.id)
  end

  test "retains app preferences referenced as audit subjects or actors" do
    now = AppPreference.database_now
    AppPreferenceStatus.ensure_defaults!
    subject_preference = AppPreference.create!(
      status_id: AppPreference::ACTIVE_STATUS_ID,
      jti: SecureRandom.uuid,
      last_issued_at: now - 431.days,
      last_issued_expires_at: now - 31.days,
    )
    actor_preference = AppPreference.create!(
      status_id: AppPreference::ACTIVE_STATUS_ID,
      jti: SecureRandom.uuid,
      last_issued_at: now - 431.days,
      last_issued_expires_at: now - 31.days,
    )
    unrelated_subject_preference = AppPreference.create!(
      status_id: AppPreference::ACTIVE_STATUS_ID,
      jti: SecureRandom.uuid,
      last_issued_at: now - 431.days,
      last_issued_expires_at: now - 31.days,
    )
    AppPreferenceChronicleEvent.ensure_defaults!
    AppPreferenceChronicleLevel.ensure_defaults!
    chronicle_now = ChronicleRecord.database_now
    subject_audit = AppPreferenceChronicle.create!(
      subject_id: subject_preference.id,
      subject_type: "AppPreference",
      event_id: AppPreferenceChronicleEvent::RESET_BY_USER_DECISION,
      level_id: AppPreferenceChronicleLevel::INFO,
      occurred_at: chronicle_now,
      discard_at: chronicle_now,
      purge_eligible_at: chronicle_now + 7.years,
    )
    actor_audit = AppPreferenceChronicle.create!(
      subject_id: actor_preference.id + 100_000,
      subject_type: "IndependentAuditSubject",
      actor_id: actor_preference.id,
      actor_type: "AppPreference",
      event_id: AppPreferenceChronicleEvent::RESET_BY_USER_DECISION,
      level_id: AppPreferenceChronicleLevel::INFO,
      occurred_at: chronicle_now,
      discard_at: chronicle_now,
      purge_eligible_at: chronicle_now + 7.years,
    )
    unrelated_subject_audit = AppPreferenceChronicle.create!(
      subject_id: unrelated_subject_preference.id,
      subject_type: "IndependentAuditSubject",
      event_id: AppPreferenceChronicleEvent::RESET_BY_USER_DECISION,
      level_id: AppPreferenceChronicleLevel::INFO,
      occurred_at: chronicle_now,
      discard_at: chronicle_now,
      purge_eligible_at: chronicle_now + 7.years,
    )

    PreferenceLifecycleJob.perform_now

    assert_predicate AppPreference.where(id: subject_preference.id), :exists?
    assert_predicate AppPreference.where(id: actor_preference.id), :exists?
    assert_not AppPreference.exists?(unrelated_subject_preference.id)
    assert_predicate AppPreferenceChronicle.where(id: subject_audit.id), :exists?
    assert_predicate AppPreferenceChronicle.where(id: actor_audit.id), :exists?
    assert_predicate AppPreferenceChronicle.where(id: unrelated_subject_audit.id), :exists?
    app_with_dependencies = AppPreference.preload(*PreferenceLifecyclePurger::APP_DEPENDENCIES).find(subject_preference.id)
    assert_raises(ActiveRecord::DeleteRestrictionError) { app_with_dependencies.destroy! }
    assert_predicate AppPreference.where(id: subject_preference.id), :exists?
    assert_raises(ActiveRecord::RecordNotFound) do
      actor_audit.update!(actor_id: actor_preference.id + 1_000_000, discard_at: ChronicleRecord.database_now + 1.day)
    end
    assert_equal actor_preference.id, actor_audit.reload.actor_id
  end

  test "collects org preferences at and after the 30-day retention boundary" do
    now = OrgPreference.database_now.change(usec: 0)
    OrgPreferenceStatus.ensure_defaults!
    OrgPreferenceThemeOption.ensure_defaults!
    before = OrgPreference.create!(
      status_id: OrgPreference::ACTIVE_STATUS_ID,
      jti: SecureRandom.uuid,
      last_issued_at: now - 430.days + Rational(1, 1_000_000),
      last_issued_expires_at: now - 30.days + Rational(1, 1_000_000),
    )
    at = OrgPreference.create!(
      status_id: OrgPreference::ACTIVE_STATUS_ID,
      jti: SecureRandom.uuid,
      last_issued_at: now - 430.days,
      last_issued_expires_at: now - 30.days,
    )
    after = OrgPreference.create!(
      status_id: OrgPreference::RETIRED_STATUS_ID,
      jti: SecureRandom.uuid,
      last_issued_at: now - 430.days - Rational(1, 1_000_000),
      last_issued_expires_at: now - 30.days - Rational(1, 1_000_000),
    )
    child = OrgPreferenceTheme.create!(preference_id: after.id, option_id: OrgPreferenceThemeOption::DARK)

    OrgPreference.stub(:database_now, now) do
      assert_operator PreferenceLifecycleJob.perform_now, :>=, 2
    end

    assert_predicate OrgPreference.where(id: before.id), :exists?
    assert_not OrgPreference.exists?(at.id)
    assert_not OrgPreference.exists?(after.id)
    assert_not OrgPreferenceTheme.exists?(child.id)
  end

  test "retains org preferences referenced as audit subjects or actors" do
    now = OrgPreference.database_now
    OrgPreferenceStatus.ensure_defaults!
    subject_preference = OrgPreference.create!(
      status_id: OrgPreference::ACTIVE_STATUS_ID,
      jti: SecureRandom.uuid,
      last_issued_at: now - 431.days,
      last_issued_expires_at: now - 31.days,
    )
    actor_preference = OrgPreference.create!(
      status_id: OrgPreference::ACTIVE_STATUS_ID,
      jti: SecureRandom.uuid,
      last_issued_at: now - 431.days,
      last_issued_expires_at: now - 31.days,
    )
    unrelated_subject_preference = OrgPreference.create!(
      status_id: OrgPreference::ACTIVE_STATUS_ID,
      jti: SecureRandom.uuid,
      last_issued_at: now - 431.days,
      last_issued_expires_at: now - 31.days,
    )
    OrgPreferenceChronicleEvent.ensure_defaults!
    OrgPreferenceChronicleLevel.ensure_defaults!
    chronicle_now = ChronicleRecord.database_now
    subject_audit = OrgPreferenceChronicle.create!(
      subject_id: subject_preference.id,
      subject_type: "OrgPreference",
      event_id: OrgPreferenceChronicleEvent::RESET_BY_USER_DECISION,
      level_id: OrgPreferenceChronicleLevel::INFO,
      occurred_at: chronicle_now,
      discard_at: chronicle_now,
      purge_eligible_at: chronicle_now + 7.years,
    )
    actor_audit = OrgPreferenceChronicle.create!(
      subject_id: actor_preference.id + 100_000,
      subject_type: "IndependentAuditSubject",
      actor_id: actor_preference.id,
      actor_type: "OrgPreference",
      event_id: OrgPreferenceChronicleEvent::RESET_BY_USER_DECISION,
      level_id: OrgPreferenceChronicleLevel::INFO,
      occurred_at: chronicle_now,
      discard_at: chronicle_now,
      purge_eligible_at: chronicle_now + 7.years,
    )
    unrelated_subject_audit = OrgPreferenceChronicle.create!(
      subject_id: unrelated_subject_preference.id,
      subject_type: "IndependentAuditSubject",
      event_id: OrgPreferenceChronicleEvent::RESET_BY_USER_DECISION,
      level_id: OrgPreferenceChronicleLevel::INFO,
      occurred_at: chronicle_now,
      discard_at: chronicle_now,
      purge_eligible_at: chronicle_now + 7.years,
    )

    PreferenceLifecycleJob.perform_now

    assert_predicate OrgPreference.where(id: subject_preference.id), :exists?
    assert_predicate OrgPreference.where(id: actor_preference.id), :exists?
    assert_not OrgPreference.exists?(unrelated_subject_preference.id)
    assert_predicate OrgPreferenceChronicle.where(id: subject_audit.id), :exists?
    assert_predicate OrgPreferenceChronicle.where(id: actor_audit.id), :exists?
    assert_predicate OrgPreferenceChronicle.where(id: unrelated_subject_audit.id), :exists?
    org_with_dependencies = OrgPreference.preload(*PreferenceLifecyclePurger::ORG_DEPENDENCIES).find(subject_preference.id)
    assert_raises(ActiveRecord::DeleteRestrictionError) { org_with_dependencies.destroy! }
    assert_predicate OrgPreference.where(id: subject_preference.id), :exists?
    assert_raises(ActiveRecord::RecordNotFound) do
      actor_audit.update!(actor_id: actor_preference.id + 1_000_000, discard_at: ChronicleRecord.database_now + 1.day)
    end
    assert_equal actor_preference.id, actor_audit.reload.actor_id
  end

  test "collects at and after the retention deadline but not one microsecond before it" do
    decision_time = ComPreference.database_now.change(usec: 0)
    deadline_expiry = decision_time - 30.days
    before = ComPreference.create!(
      jti: SecureRandom.uuid, last_issued_at: deadline_expiry - 400.days,
      last_issued_expires_at: deadline_expiry + Rational(1, 1_000_000),
    )
    at = ComPreference.create!(
      jti: SecureRandom.uuid, last_issued_at: deadline_expiry - 400.days, last_issued_expires_at: deadline_expiry,
    )
    after = ComPreference.create!(
      jti: SecureRandom.uuid, last_issued_at: deadline_expiry - 400.days,
      last_issued_expires_at: deadline_expiry - Rational(1, 1_000_000),
    )

    ComPreference.stub(:database_now, decision_time) do
      assert_equal 2, PreferenceLifecycleJob.perform_now
    end

    assert_predicate ComPreference.where(id: before.id), :exists?
    assert_not ComPreference.exists?(at.id)
    assert_not ComPreference.exists?(after.id)
  end

  test "collects expired preferences and children while preserving unexpired rows" do
    now = ComPreference.database_now
    expired = create_preference(now - 31.days)
    retired = create_preference(now - 31.days, status: ComPreferenceStatus::RETIRED)
    current = create_preference(now - 29.days)
    ComPreferenceAdultContentGateOption.ensure_defaults!
    cookie = ComPreferenceCookie.create!(preference: expired)
    binding = ComPreferenceBrowserBinding.create!(preference: expired, digest: "a" * 64)
    receipt = ComPreferenceConsentReceipt.create!(preference: expired, version: SecureRandom.uuid, recorded_at: now)
    dormant_gate = ComPreferenceAdultContentGate.create!(preference: expired)

    assert_equal 2, PreferenceLifecycleJob.perform_now
    assert_not ComPreference.exists?(expired.id)
    assert_not ComPreference.exists?(retired.id)
    assert_not ComPreferenceCookie.exists?(cookie.id)
    assert_not ComPreferenceBrowserBinding.exists?(binding.id)
    assert_not ComPreferenceConsentReceipt.exists?(receipt.id)
    assert_not ComPreferenceAdultContentGate.exists?(dormant_gate.id)
    assert_predicate ComPreference.where(id: current.id), :exists?
    assert_equal 0, PreferenceLifecycleJob.perform_now
  end

  test "processes beyond a full batch even when an earlier preference has audit history" do
    now = ComPreference.database_now
    retained = create_preference(now - 31.days)
    ComPreferenceChronicle.create!(
      subject_type: "ComPreference", subject_id: retained.id,
      event_id: ComPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
      level_id: ComPreferenceChronicleLevel::INFO, occurred_at: now,
    )
    ids = 200.times.map { create_preference(now - 31.days).id }

    assert_equal 200, PreferenceLifecycleJob.perform_now
    assert_predicate ComPreference.where(id: retained.id), :exists?
    assert_not ComPreference.exists?(id: ids)
  end

  test "retains an expired preference with audit history" do
    now = ComPreference.database_now
    preference = create_preference(now - 31.days)
    audit = ComPreferenceChronicle.create!(
      subject_type: "ComPreference", subject_id: preference.id,
      event_id: ComPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
      level_id: ComPreferenceChronicleLevel::INFO, occurred_at: now,
    )

    assert_equal 0, PreferenceLifecycleJob.perform_now
    assert_predicate ComPreference.where(id: preference.id), :exists?
    assert_predicate ComPreferenceChronicle.where(id: audit.id), :exists?
  end

  test "purges an expired preference without deleting a different typed audit subject with the same id" do
    now = ComPreference.database_now
    preference = create_preference(now - 31.days)
    audit = ComPreferenceChronicle.create!(
      subject_type: "OtherType", subject_id: preference.id,
      event_id: ComPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
      level_id: ComPreferenceChronicleLevel::INFO, occurred_at: now,
    )

    PreferenceLifecycleJob.perform_now

    assert_not ComPreference.exists?(preference.id)
    assert_predicate ComPreferenceChronicle.where(id: audit.id), :exists?
  end

  test "retains an expired preference referenced as an audit actor" do
    now = ComPreference.database_now
    preference = create_preference(now - 31.days)
    audit = ComPreferenceChronicle.create!(
      subject_type: "OtherType", subject_id: preference.id + 100_000,
      actor_type: "ComPreference", actor_id: preference.id,
      event_id: ComPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
      level_id: ComPreferenceChronicleLevel::INFO, occurred_at: now,
    )

    assert_equal 0, PreferenceLifecycleJob.perform_now
    assert_predicate ComPreference.where(id: preference.id), :exists?
    assert_predicate ComPreferenceChronicle.where(id: audit.id), :exists?
  end

  test "an audit cannot introduce a missing preference actor after collection" do
    now = ComPreference.database_now
    preference = create_preference(now - 31.days)

    assert_equal 1, PreferenceLifecycleJob.perform_now
    assert_raises(ActiveRecord::RecordNotFound) do
      ComPreferenceChronicle.create!(
        subject_type: "OtherType", subject_id: preference.id + 100_000,
        actor_type: "ComPreference", actor_id: preference.id,
        event_id: ComPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
        level_id: ComPreferenceChronicleLevel::INFO, occurred_at: now,
      )
    end
  end

  test "an existing audit cannot be changed to reference a collected preference actor" do
    now = ComPreference.database_now
    preference = create_preference(now - 31.days)
    audit = ComPreferenceChronicle.create!(
      subject_type: "OtherType", subject_id: preference.id + 100_000,
      actor_type: "OtherType", actor_id: preference.id,
      event_id: ComPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
      level_id: ComPreferenceChronicleLevel::INFO, occurred_at: now,
    )

    assert_equal 1, PreferenceLifecycleJob.perform_now
    assert_raises(ActiveRecord::RecordNotFound) { audit.update!(actor_type: "ComPreference") }
    assert_equal "OtherType", audit.reload.actor_type
  end

  test "a new audit cannot reference a preference after collection" do
    now = ComPreference.database_now
    preference = create_preference(now - 31.days)

    assert_equal 1, PreferenceLifecycleJob.perform_now
    assert_raises(ActiveRecord::RecordNotFound) do
      ComPreferenceChronicle.create!(
        subject_type: "ComPreference", subject_id: preference.id, actor_type: "ComPreference", actor_id: preference.id,
        event_id: ComPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
        level_id: ComPreferenceChronicleLevel::INFO, occurred_at: now,
      )
    end
  end

  private

  def create_preference(expiry, status: ComPreferenceStatus::ACTIVE)
    ComPreference.create!(
      jti: SecureRandom.uuid, status_id: status,
      last_issued_at: expiry - 400.days, last_issued_expires_at: expiry,
    )
  end
end
