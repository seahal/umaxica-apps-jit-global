# frozen_string_literal: true

require "test_helper"

class ClientSecretManualIssuanceInvalidatorTest < ActiveSupport::TestCase
  test "owner cancellation discards pending candidates clears payload releases capacity and preserves the session" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )
    raw = SecureRandom.base58(32)
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Pending fixture", password: raw,
      lookup_digest: SignSecretLookupDigest.digest(raw),
    )
    # Opaque fixture exercises removal only; no encryption format is asserted.
    issuance.update!(encrypted_payload: "opaque-test-ciphertext")
    original_token = token.attributes
    assert_difference("ClientSecretAuditOutbox.count", 2) do
      ClientSecretManualIssuanceInvalidator.call!(
        actor_context: context, token: token, issuance: issuance, purge_after: 1.day,
      )
    end
    issuance.reload
    candidate.reload

    assert_equal :canceled, issuance.state(at: Client.database_now)
    assert_nil issuance.encrypted_payload
    assert_equal issuance.canceled_at, issuance.discard_at
    assert_equal 1.day, issuance.purge_eligible_at - issuance.discard_at
    assert_equal issuance.canceled_at, candidate.discard_at
    assert_equal issuance.purge_eligible_at, candidate.purge_eligible_at
    assert_nil candidate.confirmed_at
    assert_not candidate.available_at?(at: Client.database_now)
    assert_nil ClientSecretLookupQuery.call(secret: raw)
    capacity = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)

    assert_equal 1, capacity.active_count
    assert_equal 0, capacity.reserved_count
    assert_equal original_token, token.reload.attributes
    snapshot = issuance.attributes
    assert_no_difference("ClientSecretAuditOutbox.count") do
      ClientSecretManualIssuanceInvalidator.call!(
        actor_context: context, token: token, issuance: issuance, purge_after: 2.days,
      )
    end
    assert_equal snapshot, issuance.reload.attributes

    terminal_at = issuance.canceled_at
    [nil, terminal_at - Rational(1, 1_000_000), terminal_at + Rational(1, 1_000_000)].each do |replacement|
      assert_raises(ActiveRecord::ReadonlyAttributeError) { issuance.reload[:canceled_at] = replacement }
      assert_equal terminal_at, issuance.reload.canceled_at
      assert_equal 0, issuance.reserved_count(at: Client.database_now)
    end

    rejected = ClientSecretCredential.new(
      client: actor, issuance: issuance, name: "Forbidden confirmed candidate", password: SecureRandom.base58(32),
      lookup_digest: "a" * 64, confirmed_at: Client.database_now,
    )

    assert_not rejected.valid?
    assert_includes rejected.errors.attribute_names, :issuance
  end

  test "audit failure rolls back cancellation candidate discard and payload removal" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "totp", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )
    raw = SecureRandom.base58(32)
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Pending fixture", password: raw,
      lookup_digest: SignSecretLookupDigest.digest(raw),
    )
    issuance.update!(encrypted_payload: "opaque-test-ciphertext")
    before_issuance = issuance.attributes
    before_candidate = candidate.attributes
    audit_ids = [SecureRandom.uuid, "invalid-event-uuid"]
    assert_no_difference("ClientSecretAuditOutbox.count") do
      SecureRandom.stub(:uuid, -> { audit_ids.shift }) do
        assert_raises(ActiveRecord::RecordInvalid) do
          ClientSecretManualIssuanceInvalidator.call!(
            actor_context: context, token: token, issuance: issuance, purge_after: 1.day,
          )
        end
      end
    end
    assert_equal before_issuance, issuance.reload.attributes
    assert_equal before_candidate, candidate.reload.attributes
    assert_equal 1, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
  end

  test "cancellation before generation frees capacity and a retry cannot silently start a replacement" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    operation_id = SecureRandom.uuid
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: operation_id, expires_after: 1.minute,
    )
    assert_no_difference("ClientSecretCredential.count") do
      assert_difference("ClientSecretAuditOutbox.count", 1) do
        ClientSecretManualIssuanceInvalidator.call!(
          actor_context: context, token: token, issuance: issuance, purge_after: 1.day,
        )
      end
    end
    assert_no_difference("ClientSecretIssuance.count") do
      result = ClientSecretManualReservationIssuer.call!(
        actor_context: context, token: token, operation_id: operation_id, expires_after: 1.minute,
      )

      assert_equal :canceled, result.state(at: Client.database_now)
    end
    fresh = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )

    assert_equal :pending_presentation, fresh.state(at: Client.database_now)
    assert_equal 1, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
  end

  test "current owner and scoped Step-Up are required on cancellation and its replay" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )
    [
      { last_step_up_at: nil }, { last_step_up_scope: "settings_passkey" }, { last_step_up_method: "secret" },
      { last_step_up_at: ClientToken.database_now - StepUpRequirement::DEFAULT_TTL - 1.second },
      { last_step_up_session_public_id: "another-session" }, { last_step_up_purpose: "bootstrap" },
      { last_step_up_audience: "step_up:com" }, { user_token_status_id: ClientTokenStatus::REVOKED },
      { user_token_status_id: ClientTokenStatus::RESTRICTED }, { discard_at: ClientToken.database_now },
    ].each do |mismatch|
      ClientToken.transaction(requires_new: true) do
        token.reload.update!(mismatch)
        assert_no_difference("ClientSecretAuditOutbox.count") do
          assert_raises(ClientSecretManualIssuanceInvalidator::Denied) do
            ClientSecretManualIssuanceInvalidator.call!(
              actor_context: context, token: token, issuance: issuance, purge_after: 1.day,
            )
          end
        end
        assert_nil issuance.reload.canceled_at
        raise ActiveRecord::Rollback
      end
    end
    ClientSecretManualIssuanceInvalidator.call!(
      actor_context: context, token: token.reload, issuance: issuance, purge_after: 1.day,
    )
    token.update!(last_step_up_at: nil)
    assert_no_difference("ClientSecretAuditOutbox.count") do
      assert_raises(ClientSecretManualIssuanceInvalidator::Denied) do
        ClientSecretManualIssuanceInvalidator.call!(
          actor_context: context, token: token, issuance: issuance, purge_after: 1.day,
        )
      end
    end
  end

  test "another owner or session cannot cancel a manual allocation" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    [
      { client: clients(:two), browser_session_ref: token.public_id },
      { client: actor, browser_session_ref: "another-current-session" },
    ].each do |binding|
      issuance = ClientSecretIssuance.create!(
        **binding, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
                   planned_count: 1, expires_at: Client.database_now + 1.minute,
      )
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ClientSecretManualIssuanceInvalidator::Denied) do
          ClientSecretManualIssuanceInvalidator.call!(
            actor_context: context, token: token, issuance: issuance, purge_after: 1.day,
          )
        end
      end
      assert_nil issuance.reload.canceled_at
    end
  end

  test "expiry remains an expiry and confirmed or omitted allocations cannot be canceled" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    now = Client.database_now
    expired = ClientSecretIssuance.create!(
      client: actor, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
      browser_session_ref: token.public_id, planned_count: 1, expires_at: now - 1.second,
      created_at: now - 1.minute,
    )
    snapshot = expired.attributes
    assert_no_difference("ClientSecretAuditOutbox.count") do
      result = ClientSecretManualIssuanceInvalidator.call!(
        actor_context: context, token: token, issuance: expired, purge_after: 1.day,
      )

      assert_equal :expired, result.state(at: Client.database_now)
      assert_equal snapshot, result.attributes
      assert_nil result.canceled_at
    end
    [
      { planned_count: 1, presented_at: now, confirmed_at: now, expires_at: now + 1.minute },
      { planned_count: 0 },
    ].each do |facts|
      terminal = ClientSecretIssuance.create!(
        **facts, client: actor, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
                 browser_session_ref: token.public_id,
      )
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ClientSecretManualIssuanceInvalidator::Denied) do
          ClientSecretManualIssuanceInvalidator.call!(
            actor_context: context, token: token, issuance: terminal, purge_after: 1.day,
          )
        end
      end
      assert_nil terminal.reload.canceled_at
    end
  end

  test "ordinary model cancellation requires source audit and caller retention requires positive finite duration" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )

    assert_raises(ActiveRecord::RecordInvalid) { issuance.update!(canceled_at: Client.database_now) }
    assert_nil issuance.reload.canceled_at
    [nil, "", 0, [], {}, -1.second, 0.seconds, Float::INFINITY.seconds].each do |duration|
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ArgumentError) do
          ClientSecretManualIssuanceInvalidator.call!(
            actor_context: context, token: token, issuance: issuance, purge_after: duration,
          )
        end
      end
    end
    result = ClientSecretManualIssuanceInvalidator.call!(
      actor_context: context, token: token, issuance: issuance, purge_after: 0.000001.seconds,
    )

    assert_equal Rational(1, 1_000_000), result.purge_eligible_at.to_r - result.discard_at.to_r
  end
end
