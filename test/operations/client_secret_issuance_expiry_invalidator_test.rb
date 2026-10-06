# frozen_string_literal: true

require "test_helper"

class ClientSecretIssuanceExpiryInvalidatorTest < ActiveSupport::TestCase
  test "expired allocation is retired with anonymous executor attribution and replay preserves its deadline" do
    actor = clients(:one)
    now = Client.database_now
    issuance = ClientSecretIssuance.create!(
      client: actor, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
      browser_session_ref: "expired-browser", planned_count: 1,
      expires_at: now - 1.second, created_at: now - 1.minute,
      encrypted_payload: "opaque-removal-fixture",
    )
    raw = SecureRandom.base58(32)
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Unconfirmed fixture", password: raw,
    )
    executor_id = ApplicationJob.new.job_id
    before_active = ClientSecretCapacityQuery.call(client: actor, at: now).active_count
    assert_difference("ClientSecretAuditOutbox.count", 2) do
      result = ClientSecretIssuanceExpiryInvalidator.call!(
        issuance: issuance, executor_job_id: executor_id, purge_after: 1.day,
      )

      assert_equal issuance.id, result.id
    end
    issuance.reload
    candidate.reload

    assert_equal :expired, issuance.state(at: Client.database_now)
    assert_nil issuance.canceled_at
    assert_nil issuance.encrypted_payload
    assert_equal issuance.discard_at, candidate.discard_at
    assert_equal 1.day, issuance.purge_eligible_at - issuance.discard_at
    assert_equal issuance.purge_eligible_at, candidate.purge_eligible_at
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
    events = ClientSecretAuditOutbox.where(operation_ref: issuance.origin_operation_id).order(:id).to_a

    assert_equal [nil, candidate.public_id], events.map(&:credential_ref)
    assert_equal [1, nil], events.map(&:item_count)
    events.each do |event|
      assert_equal "secret.discarded", event.event_name
      assert_equal "flow_expired", event.reason
      assert_equal executor_id, event.executor_job_id
      assert_nil event.actor_type
      assert_nil event.actor_id
      assert_nil event.actor_public_ref
    end
    snapshots = [issuance.attributes, candidate.attributes]
    assert_no_difference("ClientSecretAuditOutbox.count") do
      ClientSecretIssuanceExpiryInvalidator.call!(
        issuance: issuance, executor_job_id: ApplicationJob.new.job_id, purge_after: 2.days,
      )
    end
    assert_equal snapshots, [issuance.reload.attributes, candidate.reload.attributes]
    capacity = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)

    assert_equal before_active, capacity.active_count
    assert_equal 0, capacity.reserved_count
  end

  test "writer clock immediately before at and after expiry controls retirement without fabricating cancellation" do
    actor = clients(:one)
    deadline = Client.database_now + 1.minute
    issuance = ClientSecretIssuance.create!(
      client: actor, origin_operation_id: SecureRandom.uuid, origin: "passkey_registration", attempt_number: 1,
      browser_session_ref: "expiry-boundary-browser", planned_count: 2, expires_at: deadline,
    )
    # The writer clock seam controls microsecond boundaries; real clock/concurrency
    # coverage is separate from these deterministic timestamp partitions.
    [-1, 0, 1].each do |offset|
      ClientSecretIssuance.transaction(requires_new: true) do
        at = deadline + Rational(offset, 1_000_000)
        Client.stub(:database_now, at) do
          if offset.negative?
            assert_no_difference("ClientSecretAuditOutbox.count") do
              assert_raises(ClientSecretIssuanceExpiryInvalidator::NotExpired) do
                ClientSecretIssuanceExpiryInvalidator.call!(
                  issuance: issuance, executor_job_id: ApplicationJob.new.job_id, purge_after: 1.day,
                )
              end
            end
            assert_equal 2, issuance.reload.reserved_count(at: at)
          else
            assert_difference("ClientSecretAuditOutbox.count", 1) do
              ClientSecretIssuanceExpiryInvalidator.call!(
                issuance: issuance, executor_job_id: ApplicationJob.new.job_id, purge_after: 1.day,
              )
            end
            assert_equal at, issuance.reload.discard_at
            assert_equal 0, issuance.reserved_count(at: at)
            assert_nil issuance.canceled_at
          end
        end
        raise ActiveRecord::Rollback
      end
    end
  end

  test "source audit failure rolls back candidate retirement and ciphertext removal" do
    actor = clients(:one)
    now = Client.database_now
    issuance = ClientSecretIssuance.create!(
      client: actor, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
      browser_session_ref: "expired-browser", planned_count: 1,
      expires_at: now - 1.second, created_at: now - 1.minute, encrypted_payload: "opaque-removal-fixture",
    )
    raw = SecureRandom.base58(32)
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Unconfirmed fixture", password: raw,
    )
    snapshots = [issuance.attributes, candidate.attributes]
    audit_ids = [SecureRandom.uuid, "invalid-event-uuid"]
    assert_no_difference("ClientSecretAuditOutbox.count") do
      SecureRandom.stub(:uuid, -> { audit_ids.shift }) do
        assert_raises(ActiveRecord::RecordInvalid) do
          ClientSecretIssuanceExpiryInvalidator.call!(
            issuance: issuance, executor_job_id: "actual-job-execution", purge_after: 1.day,
          )
        end
      end
    end
    assert_equal snapshots, [issuance.reload.attributes, candidate.reload.attributes]
  end

  test "live confirmed omitted and canceled issuances are not reclassified by expiry cleanup" do
    actor = clients(:one)
    now = Client.database_now
    [
      { planned_count: 1, expires_at: now + 1.minute },
      { planned_count: 1,
        expires_at: now - 1.second,
        presented_at: now - 3.seconds,
        confirmed_at: now - 2.seconds, },
      { planned_count: 0 },
      { planned_count: 1, expires_at: now - 1.second, canceled_at: now - 2.seconds },
    ].each do |facts|
      issuance = ClientSecretIssuance.create!(
        **facts, client: actor, origin_operation_id: SecureRandom.uuid, origin: "passkey_registration",
                 attempt_number: 1, browser_session_ref: "terminal-browser", created_at: now - 1.minute,
      )
      snapshot = issuance.attributes
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ClientSecretIssuanceExpiryInvalidator::NotExpired) do
          ClientSecretIssuanceExpiryInvalidator.call!(
            issuance: issuance, executor_job_id: ApplicationJob.new.job_id, purge_after: 1.day,
          )
        end
      end
      assert_equal snapshot, issuance.reload.attributes
    end
  end

  test "expiry refuses finalized candidates missing retirement proof and invalid caller inputs" do
    actor = clients(:one)
    now = Client.database_now
    issuance = ClientSecretIssuance.create!(
      client: actor, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
      browser_session_ref: "expired-browser", planned_count: 1,
      expires_at: now - 1.second, created_at: now - 1.minute,
    )
    raw = SecureRandom.base58(32)
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Inconsistent fixture", password: raw,
      confirmed_at: now,
    )
    assert_no_difference("ClientSecretAuditOutbox.count") do
      assert_raises(ClientSecretIssuanceExpiryInvalidator::InvalidState) do
        ClientSecretIssuanceExpiryInvalidator.call!(
          issuance: issuance, executor_job_id: ApplicationJob.new.job_id, purge_after: 1.day,
        )
      end
    end
    candidate.destroy!
    issuance.update!(discard_at: now, purge_eligible_at: now + 1.day)
    assert_raises(ClientSecretIssuanceExpiryInvalidator::InvalidState) do
      ClientSecretIssuanceExpiryInvalidator.call!(
        issuance: issuance, executor_job_id: ApplicationJob.new.job_id, purge_after: 1.day,
      )
    end
    [nil, "", 0, [], {}, "job\0id", "a" * 256].each do |executor_id|
      assert_raises(ArgumentError) do
        ClientSecretIssuanceExpiryInvalidator.call!(
          issuance: issuance, executor_job_id: executor_id, purge_after: 1.day,
        )
      end
    end
    [nil, "", 0, [], {}, -1.second, 0.seconds, Float::INFINITY.seconds].each do |duration|
      assert_raises(ArgumentError) do
        ClientSecretIssuanceExpiryInvalidator.call!(
          issuance: issuance, executor_job_id: ApplicationJob.new.job_id, purge_after: duration,
        )
      end
    end
    [nil, "", 0, [], {}, ClientSecretIssuance.new].each do |unbound|
      assert_raises(ArgumentError) do
        ClientSecretIssuanceExpiryInvalidator.call!(
          issuance: unbound, executor_job_id: ApplicationJob.new.job_id, purge_after: 1.day,
        )
      end
    end
  end
end
