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
    cookie = ComPreferenceCookie.create!(preference: expired)
    binding = ComPreferenceBrowserBinding.create!(preference: expired, digest: "a" * 64)
    receipt = ComPreferenceConsentReceipt.create!(preference: expired, version: SecureRandom.uuid, recorded_at: now)

    assert_equal 2, PreferenceLifecycleJob.perform_now
    assert_not ComPreference.exists?(expired.id)
    assert_not ComPreference.exists?(retired.id)
    assert_not ComPreferenceCookie.exists?(cookie.id)
    assert_not ComPreferenceBrowserBinding.exists?(binding.id)
    assert_not ComPreferenceConsentReceipt.exists?(receipt.id)
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

  test "retains an expired preference when an audit has the same subject identifier" do
    now = ComPreference.database_now
    preference = create_preference(now - 31.days)
    audit = ComPreferenceChronicle.create!(
      subject_type: "OtherType", subject_id: preference.id,
      event_id: ComPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
      level_id: ComPreferenceChronicleLevel::INFO, occurred_at: now,
    )

    assert_equal 0, PreferenceLifecycleJob.perform_now
    assert_predicate ComPreference.where(id: preference.id), :exists?
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
