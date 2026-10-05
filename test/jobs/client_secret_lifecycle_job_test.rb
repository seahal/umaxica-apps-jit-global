# frozen_string_literal: true

require "test_helper"

class ClientSecretLifecycleJobTest < ActiveJob::TestCase
  test "lifecycle continuation validates batch cursor and phase boundaries before writes" do
    keys = %w(APP_SECRET_PURGE_DELAY_SECONDS APP_SECRET_OUTBOX_RETENTION_SECONDS APP_SECRET_PROOF_RETENTION_SECONDS)
    previous = ENV.to_h.slice(*keys)
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = "604800"
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = "2592000"

    [0, 501, nil, "1", 0.5].each do |value|
      assert_raises(ArgumentError) { ClientSecretLifecycleJob.perform_now(batch_size: value) }
    end
    [-1, nil, "0", 0.5].each do |value|
      assert_raises(ArgumentError) { ClientSecretLifecycleJob.perform_now(after_id: value) }
    end
    [-1, "1", 0.5].each do |value|
      assert_raises(ArgumentError) { ClientSecretLifecycleJob.perform_now(through_id: value) }
    end
    ["", "receipt", 0, [], {}].each do |value|
      assert_raises(ArgumentError) { ClientSecretLifecycleJob.perform_now(phase: value) }
    end
    assert_raises(ArgumentError) { ClientSecretLifecycleJob.perform_now(after_id: 1, through_id: 0) }
    %w(credentials signup receipts).each do |phase|
      [1, 2, 499, 500].each do |batch_size|
        [[0, 0], [0, 1], [1, 1]].each do |after_id, through_id|
          assert_no_enqueued_jobs do
            ClientSecretLifecycleJob.perform_now(
              batch_size: batch_size, phase: phase, after_id: after_id, through_id: through_id,
            )
          end
        end
      end
    end
  ensure
    keys.each { |key| ENV[key] = previous[key] }
  end

  test "signup continuation passes a live allocation and retires a later canceled signup" do
    keys = %w(APP_SECRET_PURGE_DELAY_SECONDS APP_SECRET_OUTBOX_RETENTION_SECONDS APP_SECRET_PROOF_RETENTION_SECONDS)
    previous = ENV.to_h.slice(*keys)
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = "604800"
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = "2592000"
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    flows =
      [clients(:one), clients(:two)].map do |actor|
        now = ClientSignUpFlow.database_now
        ClientSignUpFlow.create!(
          principal_id: actor.id, entry_method: "email", state: "STARTED", step: "start",
          nonce_digest: SecureRandom.hex(32), issued_at: now, expires_at: now + 1.minute,
          completed_requirements: [],
        )
      end
    allocations =
      flows.map do |flow|
        ClientSecretIssuance.create!(
          client_id: flow.principal_id, origin: "passkey_registration", origin_operation_id: SecureRandom.uuid,
          attempt_number: 1, sign_up_flow_ref: flow.public_id, planned_count: 0,
        )
      end
    flows.last.transition_to!("CANCELLED", now: ClientSignUpFlow.database_now)

    assert_predicate flows.last.reload, :sign_up_cancelled?
    ClientSecretLifecycleJob.perform_now(batch_size: 1)
    while enqueued_jobs.any? { |entry| entry.fetch(:job) == ClientSecretLifecycleJob }
      perform_enqueued_jobs(only: ClientSecretLifecycleJob)
    end

    assert_equal Float::INFINITY, allocations.first.reload.discard_at
    assert_not_equal Float::INFINITY, allocations.last.reload.discard_at
    assert_nil allocations.last.signup_completed_at
    assert ClientSecretAuditOutbox.exists?(
      operation_ref: allocations.last.origin_operation_id, event_name: "secret.discarded", reason: "flow_canceled",
    )
    assert ClientSignUpFlow.exists?(flows.first.id)
  ensure
    keys.each { |key| ENV[key] = previous[key] }
  end

  test "credential continuation advances past a held row without deleting its audit or reservation" do
    keys = %w(APP_SECRET_PURGE_DELAY_SECONDS APP_SECRET_OUTBOX_RETENTION_SECONDS APP_SECRET_PROOF_RETENTION_SECONDS)
    previous = ENV.to_h.slice(*keys)
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = "604800"
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = "2592000"
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    credentials =
      [clients(:one), clients(:two)].map do |actor|
        now = Client.database_now
        issuance = ClientSecretIssuance.create!(
          client: actor, origin: "manual", origin_operation_id: SecureRandom.uuid,
          attempt_number: 1, browser_session_ref: "expired-test-browser", planned_count: 1,
          expires_at: now - 1.second, created_at: now - 1.minute,
        )
        raw = SecureRandom.base58(32)
        credential = ClientSecretCredential.create!(
          client: actor, issuance: issuance, name: "Expired candidate", password: raw,
          lookup_digest: SignSecretLookupDigest.digest(raw),
        )
        ClientSecretIssuanceExpiryInvalidator.call!(
          issuance: issuance, executor_job_id: "expired-fixture", purge_after: 0.000001.seconds,
        )
        credential
      end
    hold = ClientRetentionHold.create!(client: clients(:one), hold_kind: "legal_hold", reason_code: "legal_hold")
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 604_800)
    ClientSecretLifecycleJob.perform_now(batch_size: 1)
    while enqueued_jobs.any? { |entry| entry.fetch(:job) == ClientSecretLifecycleJob }
      perform_enqueued_jobs(only: ClientSecretLifecycleJob)
    end

    assert ClientSecretCredential.exists?(credentials.first.id)
    assert_not ClientSecretCredential.exists?(credentials.last.id)
    assert hold.reload.active_at?(Client.database_now)
    assert ClientSecretIssuance.exists?(credentials.first.issuance_id)
    assert ClientSecretAuditOutbox.exists?(
      credential_ref: credentials.last.public_id, event_name: "secret.purged",
    )
  ensure
    keys.each { |key| ENV[key] = previous[key] }
  end
end
