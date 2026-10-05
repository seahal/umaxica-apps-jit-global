# frozen_string_literal: true

require "test_helper"

class ClientSecretCompletedIssuancePurgerTest < ActiveSupport::TestCase
  test "signup payload failure remains collectible after later flow cancellation without rewriting its reason" do
    actor = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    telephone = actor.client_telephones.create!(
      raw_number: "+819012349876", confirm_policy: "1", confirm_using_mfa: "1",
      otp_counter: "1", otp_private_key: ROTP::Base32.random_base32,
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    passkey = actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public-key")
    nonce = SecureRandom.base58(32)
    flow = ClientSignUpFlow.create!(
      principal_id: actor.id, entry_method: "telephone", status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint", issued_at: ClientSignUpFlow.database_now, expires_at: 5.minutes.from_now,
      nonce_digest: ClientSignUpFlow.digest_nonce(nonce), pending_passkey_registration_id: passkey.id,
      pending_contact_type: "telephone", pending_contact_id: telephone.id,
      completed_requirements: { "otp" => { "cleared" => true } },
    )
    issuance = ClientSecretPasskeyReservationIssuer.call_for_sign_up!(
      flow: flow, nonce: nonce, passkey: passkey, expires_after: 1.minute,
    )
    ClientSecretPresentationIssuer.prepare_for_sign_up!(flow: flow, nonce: nonce, issuance: issuance)
    ClientSecretManualIssuanceInvalidator.call_for_sign_up_payload_failure!(
      flow: flow, nonce: nonce, issuance: issuance, purge_after: 0.000001.seconds,
    )

    assert_equal :dependent, ClientSecretIssuancePurger.call_terminated_signup!(
      issuance: issuance, executor_job_id: "live-payload-flow", retention_after: 1.second,
    )
    flow.transition_to!("CANCELLED", now: ClientSignUpFlow.database_now)
    ClientSecretPasskeyReservationIssuer.terminate_sign_up!(flow: flow, purge_after: 1.day)
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)

    ClientSecretCredential.where(issuance_id: issuance.id).find_each do |candidate|
      assert_equal :purged,
                   ClientSecretCredentialPurger.call!(credential: candidate, executor_job_id: "payload-candidate")
    end
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)

    assert_equal :pending, ClientSecretIssuancePurger.call_terminated_signup!(
      issuance: issuance, executor_job_id: "payload-proof-deadline", retention_after: 1.second,
    )
    future = [flow.expires_at, issuance.reload.purge_eligible_at].max + 2.seconds

    Client.stub(:database_now, future) do
      assert_equal :purged, ClientSecretIssuancePurger.call_terminated_signup!(
        issuance: issuance, executor_job_id: "payload-allocation", retention_after: 1.second,
      )
    end
    assert_equal ["payload_unavailable"], ClientSecretAuditOutbox.where(
      operation_ref: issuance.origin_operation_id,
      event_name: %w(secret.issuance_canceled secret.discarded),
    ).distinct.pluck(:reason)
    assert ClientPasskey.exists?(passkey.id)
  end

  test "allocation expiry preceding signup cancellation preserves its factual expiry audit during collection" do
    actor = clients(:one)
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      principal_id: actor.id, entry_method: "email", state: "STARTED", step: "start",
      nonce_digest: SecureRandom.hex(32), issued_at: now - 1.minute, expires_at: now - 2.seconds,
      completed_requirements: [],
    )
    issuance = ClientSecretIssuance.create!(
      client: actor, origin: "passkey_registration", origin_operation_id: SecureRandom.uuid,
      attempt_number: 1, sign_up_flow_ref: flow.public_id, planned_count: 1,
      expires_at: now - 2.seconds, created_at: now - 1.minute,
    )
    raw = SecureRandom.base58(32)
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Expired signup", password: raw,
      lookup_digest: SignSecretLookupDigest.digest(raw),
    )
    ClientSecretIssuanceExpiryInvalidator.call!(
      issuance: issuance, executor_job_id: "original-expiry", purge_after: 0.000001.seconds,
    )
    flow.transition_to!("CANCELLED", now: ClientSignUpFlow.database_now)
    ClientSecretPasskeyReservationIssuer.terminate_sign_up!(flow: flow, purge_after: 1.day)
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)

    assert_equal :purged, ClientSecretCredentialPurger.call!(credential: candidate, executor_job_id: "candidate")
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)

    assert_equal :purged, ClientSecretIssuancePurger.call_terminated_signup!(
      issuance: issuance, executor_job_id: "expired-then-canceled", retention_after: 0.000001.seconds,
    )
    assert ClientSecretAuditOutbox.exists?(
      operation_ref: issuance.origin_operation_id, event_name: "secret.discarded", reason: "flow_expired",
    )
    assert_not ClientSecretAuditOutbox.exists?(
      operation_ref: issuance.origin_operation_id, event_name: "secret.discarded", reason: "flow_canceled",
    )
  end

  test "canceled expired and failed signup collect zero one and two candidates without activation" do
    actor = clients(:one)
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    %w(CANCELLED EXPIRED FAILED).each do |terminal|
      [0, 1, 2].each do |count|
        now = ClientSignUpFlow.database_now
        flow = ClientSignUpFlow.create!(
          principal_id: actor.id, entry_method: "email", state: "STARTED", step: "start",
          nonce_digest: SecureRandom.hex(32), issued_at: now - 1.minute, expires_at: now - 2.seconds,
          completed_requirements: [],
        )
        facts = count.positive? ? { expires_at: now - 2.seconds } : {}
        facts.merge!(presented_at: now - 4.seconds, confirmed_at: now - 3.seconds) if count == 2
        issuance = ClientSecretIssuance.create!(
          **facts, client: actor, origin: "passkey_registration", origin_operation_id: SecureRandom.uuid,
                   attempt_number: 1, sign_up_flow_ref: flow.public_id, planned_count: count,
                   created_at: now - 1.minute,
        )
        candidates =
          count.times.map do
            raw = SecureRandom.base58(32)
            ClientSecretCredential.create!(
              client: actor, issuance: issuance, name: "Pending signup", password: raw,
              lookup_digest: SignSecretLookupDigest.digest(raw), confirmed_at: issuance.confirmed_at,
            )
          end

        assert_equal :dependent, ClientSecretIssuancePurger.call_terminated_signup!(
          issuance: issuance, executor_job_id: "live-signup", retention_after: 0.000001.seconds,
        )
        flow.transition_to!(terminal, now: ClientSignUpFlow.database_now)
        ClientSecretPasskeyReservationIssuer.terminate_sign_up!(flow: flow, purge_after: 0.000001.seconds)
        ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)

        candidates.each do |credential|
          assert_equal :purged, ClientSecretCredentialPurger.call!(credential: credential, executor_job_id: "candidate")
        end
        if count.positive?
          assert_equal :undelivered, ClientSecretIssuancePurger.call_terminated_signup!(
            issuance: issuance, executor_job_id: "before-candidate-purge-audit", retention_after: 0.000001.seconds,
          )
          ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)
        end

        assert_equal :purged, ClientSecretIssuancePurger.call_terminated_signup!(
          issuance: issuance, executor_job_id: "terminal-signup", retention_after: 0.000001.seconds,
        )
        assert_not ClientSecretIssuance.exists?(issuance.id)
        assert_nil issuance.signup_completed_at
        assert_equal terminal, ClientSignUpFlow::STATUS_NAMES.fetch(flow.reload.status_id)
        assert ClientSecretAuditOutbox.exists?(
          operation_ref: issuance.origin_operation_id, event_name: "secret.issuance_purged", item_count: count,
        )
      end
    end
  end

  test "canceled signup omission is collected only after terminal audit and proof retention" do
    previous = ENV["APP_SECRET_PROOF_RETENTION_SECONDS"]
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = "1"
    actor = clients(:one)
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      principal_id: actor.id, entry_method: "email", state: "STARTED", step: "start",
      nonce_digest: SecureRandom.hex(32), issued_at: now - 1.minute, expires_at: now - 2.seconds,
      completed_requirements: [],
    )
    issuance = ClientSecretIssuance.create!(
      client: actor, origin: "passkey_registration", origin_operation_id: SecureRandom.uuid,
      attempt_number: 1, sign_up_flow_ref: flow.public_id, planned_count: 0, created_at: now - 1.minute,
    )
    flow.transition_to!("CANCELLED", now: ClientSignUpFlow.database_now)

    assert_equal :pending, ClientSecretIssuancePurger.call_terminated_signup!(
      issuance: issuance, executor_job_id: "before-source-retirement", retention_after: 1.second,
    )
    ClientSecretPasskeyReservationIssuer.terminate_sign_up!(flow: flow, purge_after: 0.000001.seconds)
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)

    assert_equal :pending, ClientSecretIssuancePurger.call_terminated_signup!(
      issuance: issuance, executor_job_id: "before-proof-retention", retention_after: 1.second,
    )
    Timeout.timeout(3) { sleep 0.01 while Client.database_now < issuance.reload.purge_eligible_at + 1.second }

    assert_equal :undelivered, ClientSecretIssuancePurger.call_terminated_signup!(
      issuance: issuance, executor_job_id: "before-audit-delivery", retention_after: 1.second,
    )
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)
    hold = ClientRetentionHold.create!(client: actor, hold_kind: "legal_hold", reason_code: "legal_hold")

    assert_equal :held, ClientSecretIssuancePurger.call_terminated_signup!(
      issuance: issuance, executor_job_id: "held-signup", retention_after: 1.second,
    )
    hold.update!(status_id: ClientRetentionHoldStatus::RELEASED)
    assert_difference("ClientSecretIssuance.count", -1) do
      ClientSecretIssuanceCollectionJob.perform_now(batch_size: 1, after_id: issuance.id - 1, through_id: issuance.id)
    end
    assert_not ClientSecretIssuance.exists?(issuance.id)
    assert ClientSignUpFlow.exists?(flow.id)
    assert ClientSecretAuditOutbox.exists?(
      operation_ref: issuance.origin_operation_id, event_name: "secret.issuance_purged", item_count: 0,
    )
  ensure
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = previous
  end

  test "matching audit UUID alone cannot authorize collection with conflicting Chronicle facts" do
    actor = clients(:one)
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    issuance =
      ClientSecretIssuance.transaction do
        at = Client.database_now - 3.seconds
        row = ClientSecretIssuance.create!(
          client: actor, origin: "passkey_registration", origin_operation_id: SecureRandom.uuid,
          attempt_number: 1, browser_session_ref: "retired-session", planned_count: 0,
          created_at: at, updated_at: at,
        )
        ClientSecretAuditOutbox.record!(
          actor_context: ActorValuesContext.empty, client_ref: actor.public_id,
          operation_ref: row.origin_operation_id, occurred_at: at,
          event_name: "secret.issuance_omitted", reason: "capacity_full", item_count: 0,
        )
        row
      end
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)
    source = ClientSecretAuditOutbox.find_by!(operation_ref: issuance.origin_operation_id)
    chronicle = Chronicle.find_by!(event_uuid: source.event_id)
    snapshot = chronicle.attributes
    [
      { action: "secret.renamed" },
      { request_id: SecureRandom.uuid },
      { reason: "different_reason" },
      { occurred_at: chronicle.occurred_at + 1.second },
      { metadata: {} },
      { actor_type: "Client", actor_id: actor.id },
      { subject_type: "Visitor" },
      { changeset: { "unexpected" => "change" } },
    ].each do |conflicting|
      # A corrupted durable record is an input to the public purge boundary.
      chronicle.update_columns(**conflicting)

      assert_equal :undelivered, ClientSecretIssuancePurger.call_omitted!(
        issuance: issuance, executor_job_id: "conflicting-durable-audit", retention_after: 1.second,
      )
      assert ClientSecretIssuance.exists?(issuance.id)
      chronicle.update_columns(**snapshot.slice(*conflicting.keys.map(&:to_s)))
    end

    assert_equal :purged, ClientSecretIssuancePurger.call_omitted!(
      issuance: issuance, executor_job_id: "matching-durable-audit", retention_after: 1.second,
    )
    assert ClientSecretAuditOutbox.exists?(
      operation_ref: issuance.origin_operation_id, event_name: "secret.issuance_purged",
    )
  end

  test "confirmed allocation collection follows real revocation and durable credential purge audit" do
    config_keys = %w(
      APP_SECRET_PURGE_DELAY_SECONDS APP_SECRET_OUTBOX_RETENTION_SECONDS APP_SECRET_PROOF_RETENTION_SECONDS
    )
    original_config = ENV.to_h.slice(*config_keys)
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "1"
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = "3600"
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = "1"
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public-key")
    token = ClientToken.create!(user: actor)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 2.seconds,
    )
    ClientSecretPresentationIssuer.prepare!(actor_context: context, token: token, issuance: issuance)
    raw = ClientSecretPresentationIssuer.call!(actor_context: context, token: token, issuance: issuance).first
    ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance: issuance)
    credential = ClientSecretLookupQuery.call(secret: raw)
    ClientSecretRevocationCommitter.call!(
      actor_context: context, token: token, credential: credential, purge_after: 0.000001.seconds,
    )
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)

    assert_equal :purged, ClientSecretCredentialPurger.call!(credential: credential, executor_job_id: "credential")
    token.revoke!
    deadline = [issuance.reload.expires_at, token.reload.discard_at].max + 1.second
    Timeout.timeout(4) { sleep 0.01 while Client.database_now < deadline }

    assert_equal :undelivered, ClientSecretIssuancePurger.call_confirmed!(
      issuance: issuance, executor_job_id: "before-purge-audit", retention_after: 1.second,
    )
    assert ClientSecretIssuance.exists?(issuance.id)
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)

    ClientSecretLifecycleJob.perform_now(batch_size: 500)

    assert_not ClientSecretIssuance.exists?(issuance.id)
    assert_nil ClientSecretLookupQuery.call(secret: raw)
    event = ClientSecretAuditOutbox.find_by!(
      operation_ref: issuance.origin_operation_id, event_name: "secret.issuance_purged",
    )

    assert_equal 1, event.item_count
    assert_nil event.delivered_at
    assert ClientToken.exists?(token.id)
  ensure
    config_keys.each { |key| ENV[key] = original_config[key] }
  end

  test "confirmed allocation remains while its confirmed credential still exists" do
    issuance = client_secret_issuances(:one)

    assert_equal :dependent, ClientSecretIssuancePurger.call_confirmed!(
      issuance: issuance, executor_job_id: "confirmed-dependency", retention_after: 1.second,
    )
    assert ClientSecretIssuance.exists?(issuance.id)
    assert ClientSecretCredential.exists?(issuance_id: issuance.id)
    assert_not ClientSecretAuditOutbox.exists?(
      operation_ref: issuance.origin_operation_id, event_name: "secret.issuance_purged",
    )
  end

  test "signup completion audit cannot replace a missing omission audit" do
    actor = clients(:one)
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    issuance =
      ClientSecretIssuance.transaction do
        at = Client.database_now - 3.seconds
        row = ClientSecretIssuance.create!(
          client: actor, origin: "passkey_registration", origin_operation_id: SecureRandom.uuid,
          attempt_number: 1, sign_up_flow_ref: SecureRandom.base58(21), planned_count: 0,
          signup_completed_at: at, created_at: at, updated_at: at,
        )
        ClientSecretAuditOutbox.record!(
          actor_context: ActorValuesContext.empty, client_ref: actor.public_id,
          operation_ref: row.origin_operation_id, occurred_at: at,
          event_name: "secret.signup_completed", reason: "passkey_registration", item_count: 0,
        )
        row
      end
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)

    assert_equal :undelivered, ClientSecretIssuancePurger.call_omitted!(
      issuance: issuance, executor_job_id: "missing-omission", retention_after: 1.second,
    )
    assert ClientSecretIssuance.exists?(issuance.id)
    assert_not ClientSecretAuditOutbox.exists?(
      operation_ref: issuance.origin_operation_id, event_name: "secret.issuance_purged",
    )
  end

  test "an unbounded original session retains omission proof until revocation and legal hold release" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    token.schedule_retention!(discard_at: Float::INFINITY, purge_eligible_at: Float::INFINITY)
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    issuance =
      ClientSecretIssuance.transaction do
        now = Client.database_now
        row = ClientSecretIssuance.create!(
          client: actor, origin: "passkey_registration", origin_operation_id: SecureRandom.uuid,
          attempt_number: 1, browser_session_ref: token.public_id, planned_count: 0, created_at: now, updated_at: now,
        )
        ClientSecretAuditOutbox.record!(
          actor_context: ActorValuesContext.empty, client_ref: actor.public_id,
          operation_ref: row.origin_operation_id, occurred_at: now,
          event_name: "secret.issuance_omitted", reason: "capacity_full", item_count: 0,
        )
        row
      end
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)

    assert_equal :dependent, ClientSecretIssuancePurger.call_omitted!(
      issuance: issuance, executor_job_id: "unbounded-session", retention_after: 1.second,
    )
    token.revoke!
    Timeout.timeout(3) { sleep 0.01 while Client.database_now < token.reload.discard_at + 1.second }
    hold = ClientRetentionHold.create!(client: actor, hold_kind: "legal_hold", reason_code: "legal_hold")

    assert_equal :held, ClientSecretIssuancePurger.call_omitted!(
      issuance: issuance, executor_job_id: "held", retention_after: 1.second,
    )
    hold.update!(status_id: ClientRetentionHoldStatus::RELEASED)

    assert_equal :purged, ClientSecretIssuancePurger.call_omitted!(
      issuance: issuance, executor_job_id: "released", retention_after: 1.second,
    )
    assert ClientToken.exists?(token.id)
    assert ClientSecretAuditOutbox.exists?(
      operation_ref: issuance.origin_operation_id, event_name: "secret.issuance_purged", item_count: 0,
    )
  end

  test "omission collection retains a bound session through its expiry plus proof retention" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor, discard_at: ClientToken.database_now + 2.seconds)
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    issuance =
      ClientSecretIssuance.transaction do
        now = Client.database_now
        row = ClientSecretIssuance.create!(
          client: actor, origin: "passkey_registration", origin_operation_id: SecureRandom.uuid,
          attempt_number: 1, browser_session_ref: token.public_id, planned_count: 0, created_at: now, updated_at: now,
        )
        ClientSecretAuditOutbox.record!(
          actor_context: ActorValuesContext.empty, client_ref: actor.public_id,
          operation_ref: row.origin_operation_id, occurred_at: now,
          event_name: "secret.issuance_omitted", reason: "capacity_full", item_count: 0,
        )
        row
      end
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)

    assert_equal :pending, ClientSecretIssuancePurger.call_omitted!(
      issuance: issuance, executor_job_id: "live-binding", retention_after: 1.second,
    )
    Timeout.timeout(5) { sleep 0.01 while Client.database_now < token.discard_at + 1.second }

    assert_equal :purged, ClientSecretIssuancePurger.call_omitted!(
      issuance: issuance, executor_job_id: "retired-binding", retention_after: 1.second,
    )
    assert ClientToken.exists?(token.id)
  end

  test "omission proof retention rejects zero neighboring negative duration and non-duration sentinels" do
    issuance = client_secret_issuances(:one)

    [-0.000001.seconds, 0.seconds, nil, 1, Float::INFINITY.seconds].each do |duration|
      assert_raises(ArgumentError) do
        ClientSecretIssuancePurger.call_omitted!(
          issuance: issuance, executor_job_id: "invalid-retention", retention_after: duration,
        )
      end
    end
    # A microsecond is the nearest positive representable PostgreSQL timestamp increment.
    assert_equal :pending, ClientSecretIssuancePurger.call_omitted!(
      issuance: issuance, executor_job_id: "positive-retention", retention_after: 0.000001.seconds,
    )
    assert ClientSecretIssuance.exists?(issuance.id)
    assert ClientSecretCredential.exists?(issuance_id: issuance.id)
  end

  test "omitted allocation requires its durable audit and explicit retention before atomic collection" do
    actor = clients(:one)
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    issuance =
      ClientSecretIssuance.transaction do
        now = Client.database_now
        allocation = ClientSecretIssuance.create!(
          client: actor, origin: "passkey_registration", origin_operation_id: SecureRandom.uuid,
          attempt_number: 1, browser_session_ref: "completed-issuance-session", planned_count: 0,
          created_at: now, updated_at: now,
        )
        ClientSecretAuditOutbox.record!(
          actor_context: ActorValuesContext.empty, client_ref: actor.public_id,
          operation_ref: allocation.origin_operation_id, occurred_at: now,
          event_name: "secret.issuance_omitted", reason: "capacity_full", item_count: 0,
        )
        allocation
      end

    assert_equal :pending, ClientSecretIssuancePurger.call_omitted!(
      issuance: issuance, executor_job_id: "retention", retention_after: 1.second,
    )
    Timeout.timeout(3) { sleep 0.01 while Client.database_now < issuance.created_at + 1.second }

    assert_equal :undelivered, ClientSecretIssuancePurger.call_omitted!(
      issuance: issuance, executor_job_id: "missing-audit", retention_after: 1.second,
    )
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)
    ClientSecretIssuance.transaction(requires_new: true) do
      assert_equal :purged, ClientSecretIssuancePurger.call_omitted!(
        issuance: issuance, executor_job_id: "rollback", retention_after: 1.second,
      )
      assert_not ClientSecretIssuance.exists?(issuance.id)
      assert ClientSecretAuditOutbox.exists?(
        operation_ref: issuance.origin_operation_id, event_name: "secret.issuance_purged", item_count: 0,
      )
      raise ActiveRecord::Rollback
    end

    assert ClientSecretIssuance.exists?(issuance.id)
    assert_not ClientSecretAuditOutbox.exists?(
      operation_ref: issuance.origin_operation_id, event_name: "secret.issuance_purged",
    )
    assert_equal :purged, ClientSecretIssuancePurger.call_omitted!(
      issuance: ClientSecretIssuance.find(issuance.id), executor_job_id: "retry", retention_after: 1.second,
    )
  end
end
