# frozen_string_literal: true

require "test_helper"

class ClientSecretManualReservationIssuerTest < ActiveSupport::TestCase
  test "physically collected manual operation cannot reserve another batch on replay" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    operation = SecureRandom.uuid
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: operation, expires_after: 0.000001.seconds,
    )
    ClientSecretIssuanceExpiryInvalidator.call!(
      issuance: issuance, executor_job_id: "expire-replay", purge_after: 0.000001.seconds,
    )
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 60)

    assert_equal :purged, ClientSecretIssuancePurger.call!(issuance: issuance, executor_job_id: "purge-replay")
    assert_no_difference("ClientSecretIssuance.count") do
      assert_raises(ClientSecretManualReservationIssuer::Denied) do
        ClientSecretManualReservationIssuer.call!(
          actor_context: context, token: token, operation_id: operation, expires_after: 1.minute,
        )
      end
    end
  end

  test "scoped session reserves one item and retries preserve its allocation without generating a Secret" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    operation_id = SecureRandom.uuid
    original_token = token.attributes
    issuance = nil

    assert_no_difference("ClientSecretCredential.count") do
      assert_difference("ClientSecretIssuance.count", 1) do
        assert_difference("ClientSecretAuditOutbox.count", 1) do
          issuance = ClientSecretManualReservationIssuer.call!(
            actor_context: context, token: token, operation_id: operation_id, expires_after: 1.minute,
          )
        end
      end
    end
    assert_equal actor.id, issuance.client_id
    assert_equal token.public_id, issuance.browser_session_ref
    assert_nil issuance.sign_up_flow_ref
    assert_equal 1, issuance.planned_count
    assert_equal "manual", issuance.origin
    assert_equal 1, issuance.attempt_number
    assert_nil issuance.encrypted_payload
    assert_equal :pending_presentation, issuance.state(at: Client.database_now)
    capacity = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)

    assert_equal 1, capacity.active_count
    assert_equal 1, capacity.reserved_count
    event = ClientSecretAuditOutbox.find_by!(operation_ref: operation_id)

    assert_equal "secret.issuance_started", event.event_name
    assert_equal "manual", event.reason
    assert_equal 1, event.item_count
    assert_equal actor.public_id, event.actor_public_ref
    snapshot = issuance.attributes
    assert_no_difference("ClientSecretIssuance.count") do
      assert_no_difference("ClientSecretAuditOutbox.count") do
        replay = ClientSecretManualReservationIssuer.call!(
          actor_context: context, token: token, operation_id: operation_id, expires_after: 2.minutes,
        )

        assert_equal snapshot, replay.attributes
      end
    end
    assert_equal original_token, token.reload.attributes
  end

  test "another operation conflicts with a live reservation and cannot allocate a second batch" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "totp", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: false, last_step_up_user_verified: false,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )

    assert_no_difference("ClientSecretIssuance.count") do
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ClientSecretIssuanceCountValue::ReservationConflict) do
          ClientSecretManualReservationIssuer.call!(
            actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
          )
        end
      end
    end
    assert_equal 1, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
  end

  test "absent stale wrong method scope audience or session Step-Up cannot reserve capacity" do
    actor = clients(:one)
    token = client_tokens(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    [
      { last_step_up_at: nil }, { last_step_up_scope: "settings_passkey" },
      { last_step_up_method: "secret" }, { last_step_up_audience: "step_up:com" },
      { last_step_up_purpose: "bootstrap" }, { last_step_up_session_public_id: "another-session" },
      { last_step_up_at: ClientToken.database_now - StepUpRequirement::DEFAULT_TTL - 1.second },
      { user_token_status_id: ClientTokenStatus::REVOKED },
      { user_token_status_id: ClientTokenStatus::RESTRICTED },
      { discard_at: ClientToken.database_now },
    ].each do |mismatch|
      ClientToken.transaction(requires_new: true) do
        token.reload.update!(
          {
            last_step_up_at: ClientToken.database_now,
            last_step_up_scope: "settings_secret_credential",
            last_step_up_method: "passkey",
            last_step_up_session_public_id: token.public_id,
            last_step_up_purpose: "step_up",
            last_step_up_audience: "step_up:app",
            last_step_up_phishing_resistant: true,
            last_step_up_user_verified: true,
            last_step_up_credential_ref: "test-step-up",
            last_step_up_full_reauthentication: false,
          }.merge(mismatch),
        )
        assert_no_difference("ClientSecretIssuance.count") do
          assert_no_difference("ClientSecretAuditOutbox.count") do
            assert_raises(ClientSecretManualReservationIssuer::Denied) do
              ClientSecretManualReservationIssuer.call!(
                actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
              )
            end
          end
        end
        raise ActiveRecord::Rollback
      end
    end
  end

  test "operation from another owner or another current session never returns that reservation" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    [
      { client: clients(:two), browser_session_ref: token.public_id },
      { client: actor, browser_session_ref: "another-current-session" },
    ].each do |binding|
      operation_id = SecureRandom.uuid
      ClientSecretIssuance.create!(
        **binding, origin_operation_id: operation_id, origin: "manual", attempt_number: 1,
                   planned_count: 1, expires_at: Client.database_now + 1.minute,
      )
      assert_no_difference("ClientSecretIssuance.count") do
        assert_no_difference("ClientSecretAuditOutbox.count") do
          assert_raises(ClientSecretManualReservationIssuer::Denied) do
            ClientSecretManualReservationIssuer.call!(
              actor_context: context, token: token, operation_id: operation_id, expires_after: 1.minute,
            )
          end
        end
      end
    end
  end

  test "absent actor wrong owner surface and missing session cannot start a reservation" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)

    [
      [nil, token], [ActorValuesContext.empty, token], [context.with(subject: clients(:two)), token],
      [context.with(tld: :com), token], [context.with(surface: :sign), token], [context, nil], [context, 0],
    ].each do |binding, session|
      assert_no_difference("ClientSecretIssuance.count") do
        assert_no_difference("ClientSecretAuditOutbox.count") do
          assert_raises(ClientSecretManualReservationIssuer::Denied) do
            ClientSecretManualReservationIssuer.call!(
              actor_context: binding, token: session, operation_id: SecureRandom.uuid, expires_after: 1.minute,
            )
          end
        end
      end
    end
  end

  test "expired allocation stays expired on retry while a new operation can reserve without a cleanup job" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    operation_id = SecureRandom.uuid
    expired = ClientSecretIssuance.create!(
      client: actor, origin_operation_id: operation_id, origin: "manual", attempt_number: 1,
      browser_session_ref: token.public_id, planned_count: 1, expires_at: Client.database_now - 1.second,
    )
    snapshot = expired.attributes
    assert_no_difference("ClientSecretIssuance.count") do
      assert_no_difference("ClientSecretAuditOutbox.count") do
        replay = ClientSecretManualReservationIssuer.call!(
          actor_context: context, token: token, operation_id: operation_id, expires_after: 1.minute,
        )

        assert_equal snapshot, replay.attributes
        assert_equal :expired, replay.state(at: Client.database_now)
      end
    end
    assert_equal 0, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
    fresh = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )

    assert_equal :pending_presentation, fresh.state(at: Client.database_now)
    assert_equal 1, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
    assert_equal snapshot, expired.reload.attributes
  end

  test "duration and operation UUID boundaries reject sentinels and accept one database microsecond" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)

    [nil, "", 0, [], {}, -1.second, 0.seconds, Float::INFINITY.seconds].each do |duration|
      assert_no_difference("ClientSecretIssuance.count") do
        assert_raises(ArgumentError) do
          ClientSecretManualReservationIssuer.call!(
            actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: duration,
          )
        end
      end
    end
    [nil, "", 0, [], {}, "x" * 36, SecureRandom.uuid + "\0"].each do |operation_id|
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ArgumentError) do
          ClientSecretManualReservationIssuer.call!(
            actor_context: context, token: token, operation_id: operation_id, expires_after: 1.minute,
          )
        end
      end
    end
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 0.000001.seconds,
    )

    assert_equal Rational(1, 1_000_000), issuance.expires_at.to_r - issuance.created_at.to_r
  end

  test "source audit persistence failure rolls the new reservation back" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    operation_id = SecureRandom.uuid
    assert_no_difference("ClientSecretIssuance.count") do
      assert_no_difference("ClientSecretAuditOutbox.count") do
        SecureRandom.stub(:uuid, "invalid-event-uuid") do
          assert_raises(ActiveRecord::RecordInvalid) do
            ClientSecretManualReservationIssuer.call!(
              actor_context: context, token: token, operation_id: operation_id, expires_after: 1.minute,
            )
          end
        end
      end
    end
    assert_equal 0, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
  end

  test "manual reservation adds one at zero one eighteen nineteen and rejects twenty without a zero allocation" do
    actor = clients(:one)
    token = client_tokens(:one)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    [0, 1, 18, 19, 20].each do |count|
      AppZenithRecord.transaction(requires_new: true) do
        now = Client.database_now
        ClientSecretCredential.where(client_id: actor.id).update_all(discard_at: now)
        count.times do
          completed = ClientSecretIssuance.create!(
            client: actor, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
            browser_session_ref: token.public_id, planned_count: 1, expires_at: now + 1.minute,
            presented_at: now, confirmed_at: now,
          )
          raw = SecureRandom.base58(32)
          ClientSecretCredential.create!(
            client: actor, issuance: completed, name: "Capacity fixture", password: raw,
            confirmed_at: now,
          )
        end
        if count == 20
          assert_no_difference("ClientSecretIssuance.count") do
            assert_no_difference("ClientSecretAuditOutbox.count") do
              assert_raises(ClientSecretManualReservationIssuer::CapacityFull) do
                ClientSecretManualReservationIssuer.call!(
                  actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
                )
              end
            end
          end
          assert_equal 0, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
        else
          issuance = ClientSecretManualReservationIssuer.call!(
            actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
          )
          capacity = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)

          assert_equal 1, issuance.planned_count
          assert_equal count, capacity.active_count
          assert_equal 1, capacity.reserved_count
          assert_operator capacity.active_count + capacity.reserved_count, :<=, 20
          assert_nil issuance.encrypted_payload
          assert_equal 0, ClientSecretCredential.where(issuance_id: issuance.id).count
        end
        raise ActiveRecord::Rollback
      end
    end
  end
end
