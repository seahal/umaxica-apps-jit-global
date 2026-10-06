# frozen_string_literal: true

require "test_helper"

class ClientSecretPasskeyReservationIssuerTest < ActiveSupport::TestCase
  setup { ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400" }

  test "collected Passkey allocations cannot be recreated by signup or signed-in replay" do
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    %i(signup signed_in).each do |path|
      actor = Client.create!(status_id: (path == :signup) ? ClientStatus::UNVERIFIED_WITH_SIGN_UP : ClientStatus::ACTIVE)
      if path == :signup
        telephone = actor.client_telephones.create!(
          raw_number: "+819012349876", confirm_policy: "1", confirm_using_mfa: "1",
          otp_counter: "1", otp_private_key: ROTP::Base32.random_base32,
          user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
        )
        passkey = actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public-key")
        nonce = SecureRandom.base58(32)
        now = ClientSignUpFlow.database_now
        flow = ClientSignUpFlow.create!(
          principal_id: actor.id, entry_method: "telephone", status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
          step: "checkpoint", issued_at: now, expires_at: now + 5.minutes,
          nonce_digest: ClientSignUpFlow.digest_nonce(nonce), pending_passkey_registration_id: passkey.id,
          pending_contact_type: "telephone", pending_contact_id: telephone.id,
          completed_requirements: { "otp" => { "cleared" => true } },
        )
        issuance = ClientSecretPasskeyReservationIssuer.call_for_sign_up!(
          flow: flow, nonce: nonce, passkey: passkey, expires_after: 0.000001.seconds,
        )
      else
        token = ClientToken.create!(user: actor)
        token.update!(
          last_step_up_at: Client.database_now, last_step_up_scope: "settings_passkey",
          last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
          last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
          last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
          last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
        )
        context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
        passkey = actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public-key")
        issuance = ClientSecretPasskeyReservationIssuer.call!(
          actor_context: context, token: token, passkey: passkey, expires_after: 0.000001.seconds,
        )
      end
      ClientSecretIssuanceExpiryInvalidator.call!(
        issuance: issuance, executor_job_id: "expire-passkey-replay", purge_after: 0.000001.seconds,
      )
      ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 60)

      assert_equal :purged,
                   ClientSecretIssuancePurger.call!(issuance: issuance, executor_job_id: "purge-passkey-replay")
      assert_no_difference("ClientSecretIssuance.count") do
        error =
          assert_raises(ClientSecretPasskeyReservationIssuer::Denied) do
            if path == :signup
              ClientSecretPasskeyReservationIssuer.call_for_sign_up!(
                flow: flow, nonce: nonce, passkey: passkey, expires_after: 1.minute,
              )
            else
              ClientSecretPasskeyReservationIssuer.call!(
                actor_context: context, token: token, passkey: passkey, expires_after: 1.minute,
              )
            end
          end
        assert_equal "Secret registration allocation has already been retired", error.message
      end
    end
  end

  test "Ticket completion cannot activate a saved signup batch before source Client registration commits" do
    actor = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    now = ClientSignUpFlow.database_now
    # A cross-DB interruption can leave these Ticket facts committed while the
    # source Client remains pending; the public activation operation must refuse.
    flow = ClientSignUpFlow.create!(
      principal_id: actor.id, entry_method: "telephone", status_id: ClientSignUpFlowStatus::COMPLETED,
      step: "completed", issued_at: now - 1.minute, expires_at: now + 14.minutes,
      completed_at: now, nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.base58(32)),
    )
    issuance = ClientSecretIssuance.create!(
      client: actor, origin: "passkey_registration", origin_operation_id: SecureRandom.uuid,
      attempt_number: 1, sign_up_flow_ref: flow.public_id, planned_count: 1,
      expires_at: now + 1.minute, presented_at: now, confirmed_at: now,
    )
    raw = SecureRandom.base58(32)
    ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Saved signup Secret", password: raw,
      confirmed_at: now,
    )
    assert_no_difference("ClientSecretAuditOutbox.count") do
      assert_raises(ClientSecretPasskeyReservationIssuer::Denied) do
        ClientSecretPasskeyReservationIssuer.complete_sign_up!(flow: flow)
      end
    end
    assert_nil issuance.reload.signup_completed_at
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
    actor.update!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
    ClientSecretPasskeyReservationIssuer.complete_sign_up!(flow: flow)

    assert issuance.reload.signup_completed_at
    assert ClientSecretLookupQuery.call(client: actor, secret: raw)
    assert_equal 1, ClientSecretAuditOutbox.where(
      operation_ref: issuance.origin_operation_id, event_name: "secret.signup_completed",
    ).count
    assert_no_difference("ClientSecretAuditOutbox.count") do
      ClientSecretPasskeyReservationIssuer.complete_sign_up!(flow: flow)
    end
  end

  test "signup reservation requires its durable nonce and pending registration rather than signed-in bootstrap" do
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
    assert_no_difference("ClientSecretIssuance.count") do
      assert_raises(ClientSecretPasskeyReservationIssuer::Denied) do
        ClientSecretPasskeyReservationIssuer.call_for_sign_up!(
          flow: flow, nonce: "wrong", passkey: passkey,
          expires_after: 1.minute,
        )
      end
    end
    issuance = ClientSecretPasskeyReservationIssuer.call_for_sign_up!(
      flow: flow, nonce: nonce, passkey: passkey,
      expires_after: 1.minute,
    )

    assert_equal flow.public_id, issuance.sign_up_flow_ref
    assert_nil issuance.browser_session_ref
    assert_equal 2, issuance.planned_count
    assert_operator issuance.expires_at, :<=, flow.expires_at
    assert_nil issuance.encrypted_payload
    assert_no_difference("ClientSecretIssuance.count") do
      assert_equal issuance.id, ClientSecretPasskeyReservationIssuer.call_for_sign_up!(
        flow: flow, nonce: nonce, passkey: passkey, expires_after: 2.minutes,
      ).id
    end
    ClientSecretPresentationIssuer.prepare_for_sign_up!(flow: flow, nonce: nonce, issuance: issuance)
    assert_no_difference "ClientSecretAuditOutbox.count" do
      assert_raises(ClientSecretPasskeyReservationIssuer::Denied) do
        ClientSecretManualIssuanceInvalidator.call_for_sign_up_payload_failure!(
          flow: flow, nonce: "wrong", issuance: issuance, purge_after: 1.day,
        )
      end
    end
    assert_nil issuance.reload.canceled_at
    values = ClientSecretPresentationIssuer.present_for_sign_up!(flow: flow, nonce: nonce, issuance: issuance)

    assert_equal 2, values.length
    values.each { |value| assert_nil ClientSecretLookupQuery.call(client: actor, secret: value) }
    assert_raises(ClientSecretPasskeyReservationIssuer::Denied) do
      ClientSecretStorageConfirmationCommitter.confirm_for_sign_up!(flow: flow, nonce: "wrong", issuance: issuance)
    end
    ClientSecretStorageConfirmationCommitter.confirm_for_sign_up!(flow: flow, nonce: nonce, issuance: issuance)

    assert issuance.reload.confirmed_at
    values.each { |value| assert_nil ClientSecretLookupQuery.call(client: actor, secret: value) }
    result = SignUpCancellation.call(cycle: flow, actor_context: ActorValuesContext.empty)

    assert_predicate result, :success?
    assert_nil issuance.reload.encrypted_payload
    assert_operator issuance.discard_at, :<=, Client.database_now
    assert_equal 0, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).active_count
    assert ClientSecretCredential.where(issuance_id: issuance.id).all? { |candidate|
      candidate.discard_at <= Client.database_now
    }
    assert_equal 2, ClientSecretAuditOutbox.where(
      operation_ref: issuance.origin_operation_id, event_name: "secret.discarded", reason: "flow_canceled",
    ).where.not(credential_ref: nil).count
    assert_no_difference("ClientSecretAuditOutbox.count") {
      SignUpCancellation.call(cycle: flow, actor_context: ActorValuesContext.empty)
    }
    assert_raises(ClientSecretPasskeyReservationIssuer::Denied) do
      ClientSecretPasskeyReservationIssuer.call_for_sign_up!(
        flow: flow, nonce: nonce, passkey: passkey,
        expires_after: 1.minute,
      )
    end
  end

  test "Passkey registration reserves two one or zero from writer active count and retries keep its batch" do
    (0..20).each do |active_count|
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(user: actor)
      now = Client.database_now
      token.update!(
        last_step_up_at: now, last_step_up_scope: "settings_passkey", last_step_up_method: "passkey",
        last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
        last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: true,
        last_step_up_user_verified: true, last_step_up_credential_ref: "test-step-up",
        last_step_up_full_reauthentication: false,
      )
      context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
      active_count.times do
        # Existing confirmed holdings are setup facts; the operation under test reserves a new batch.
        prior = ClientSecretIssuance.create!(
          client: actor, origin: "manual", origin_operation_id: SecureRandom.uuid,
          attempt_number: 1, browser_session_ref: token.public_id, planned_count: 1,
          expires_at: now + 1.minute, presented_at: now, confirmed_at: now,
        )
        raw = SecureRandom.base58(32)
        ClientSecretCredential.create!(
          client: actor, issuance: prior, name: "Existing",
          password: raw, confirmed_at: now,
        )
      end
      passkey = actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "existing-public-key")
      issuance = nil
      assert_no_difference("ClientSecretCredential.count") do
        issuance = ClientSecretPasskeyReservationIssuer.call!(
          actor_context: context, token: token, passkey: passkey, expires_after: 1.minute,
        )
      end
      expected = [2, 20 - active_count].min

      assert_equal expected, issuance.planned_count, "A=#{active_count}"
      assert_equal "passkey_registration", issuance.origin
      assert_nil issuance.encrypted_payload
      assert_nil issuance.expires_at if active_count == 20

      assert_equal expected, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
      assert_no_difference("ClientSecretIssuance.count") do
        retry_issuance = ClientSecretPasskeyReservationIssuer.call!(
          actor_context: context, token: token, passkey: passkey, expires_after: 2.minutes,
        )

        assert_equal issuance.attributes, retry_issuance.attributes
      end
    end
  end
end
