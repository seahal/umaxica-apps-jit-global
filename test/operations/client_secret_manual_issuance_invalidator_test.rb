# frozen_string_literal: true

require "test_helper"

class ClientSecretManualIssuanceInvalidatorTest < ActiveSupport::TestCase
  test "a revoked device cannot cancel a Secret issuance" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    evidence =
      begin
        now = ClientToken.database_now
        token.update!(root_login_established_at: now, established_authentication_method: "passkey")
        token.rotate_refresh_token!(now: now)
        token.device_session_record!
        oidc_client = OidcClientRegistry.find!("base-app-ww")
        grant = OpAppGrant.create!(
          authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
          oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
          oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
        )
        grant.issue_refresh_token!(now: now)
        StepUpEvidenceValue.new(
          acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
          sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
          aud: [oidc_client.aud], jti: grant.oidc_jti,
        )
      end
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )
    token.device_session_record!.revoke!

    assert_no_difference "ClientSecretAuditOutbox.count" do
      assert_raises(ClientSecretManualIssuanceInvalidator::Denied) do
        ClientSecretManualIssuanceInvalidator.call!(
          actor_context: context, token: token, issuance: issuance, purge_after: 1.day,
          step_up_evidence: evidence,
        )
      end
    end
    assert_nil issuance.reload.canceled_at
  end

  test "a superseded device token cannot cancel a Secret issuance" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    evidence =
      begin
        now = ClientToken.database_now
        token.update!(root_login_established_at: now, established_authentication_method: "passkey")
        token.rotate_refresh_token!(now: now)
        token.device_session_record!
        oidc_client = OidcClientRegistry.find!("base-app-ww")
        grant = OpAppGrant.create!(
          authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
          oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
          oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
        )
        grant.issue_refresh_token!(now: now)
        StepUpEvidenceValue.new(
          acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
          sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
          aud: [oidc_client.aud], jti: grant.oidc_jti,
        )
      end
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )
    device = token.device_session_record!
    replacement = ClientToken.create!(authentication_epoch: 0, user: actor, device_session: device)
    device.update!(current_refresh_token_id: replacement.id)

    assert_no_difference "ClientSecretAuditOutbox.count" do
      assert_raises(ClientSecretManualIssuanceInvalidator::Denied) do
        ClientSecretManualIssuanceInvalidator.call!(
          actor_context: context, token: token, issuance: issuance, purge_after: 1.day,
          step_up_evidence: evidence,
        )
      end
    end
    assert_nil issuance.reload.canceled_at
  end

  test "owner cancellation discards pending candidates clears payload releases capacity and preserves the session" do
    actor = clients(:one)
    token = client_tokens(:one)
    evidence =
      begin
        now = ClientToken.database_now
        token.update!(root_login_established_at: now, established_authentication_method: "passkey")
        token.rotate_refresh_token!(now: now)
        token.device_session_record!
        oidc_client = OidcClientRegistry.find!("base-app-ww")
        grant = OpAppGrant.create!(
          authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
          oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
          oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
        )
        grant.issue_refresh_token!(now: now)
        StepUpEvidenceValue.new(
          acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
          sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
          aud: [oidc_client.aud], jti: grant.oidc_jti,
        )
      end
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )
    raw = SecureRandom.base58(32)
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Pending fixture", password: raw,
    )
    # Opaque fixture exercises removal only; no encryption format is asserted.
    issuance.update!(encrypted_payload: "opaque-test-ciphertext")
    original_token = token.attributes
    assert_difference("ClientSecretAuditOutbox.count", 2) do
      ClientSecretManualIssuanceInvalidator.call!(
        actor_context: context, token: token, issuance: issuance, purge_after: 1.day,
        step_up_evidence: evidence,
      )
    end
    issuance.reload
    candidate.reload

    assert_equal :canceled, issuance.state(at: Client.database_now)
    assert_equal ["flow_canceled"], ClientSecretAuditOutbox.where(
      operation_ref: issuance.origin_operation_id, event_name: %w(secret.issuance_canceled secret.discarded),
    ).distinct.pluck(:reason)
    assert_nil issuance.encrypted_payload
    assert_equal issuance.canceled_at, issuance.discard_at
    assert_equal 1.day, issuance.purge_eligible_at - issuance.discard_at
    assert_equal issuance.canceled_at, candidate.discard_at
    assert_equal issuance.purge_eligible_at, candidate.purge_eligible_at
    assert_nil candidate.confirmed_at
    assert_not candidate.available_at?(at: Client.database_now)
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
    capacity = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)

    assert_equal 1, capacity.active_count
    assert_equal 0, capacity.reserved_count
    assert_equal original_token, token.reload.attributes
    snapshot = issuance.attributes
    assert_no_difference("ClientSecretAuditOutbox.count") do
      ClientSecretManualIssuanceInvalidator.call!(
        actor_context: context, token: token, issuance: issuance, purge_after: 2.days,
        step_up_evidence: evidence,
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
      confirmed_at: Client.database_now,
    )

    assert_not rejected.valid?
    assert_includes rejected.errors.attribute_names, :issuance
  end

  test "payload failure retirement still requires current independent scoped Step-Up" do
    actor = clients(:one)
    token = client_tokens(:one)
    evidence =
      begin
        now = ClientToken.database_now
        token.update!(root_login_established_at: now, established_authentication_method: "passkey")
        token.rotate_refresh_token!(now: now)
        token.device_session_record!
        oidc_client = OidcClientRegistry.find!("base-app-ww")
        grant = OpAppGrant.create!(
          authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
          oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
          oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
        )
        grant.issue_refresh_token!(now: now)
        StepUpEvidenceValue.new(
          acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
          sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
          aud: [oidc_client.aud], jti: grant.oidc_jti,
        )
      end
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )
    ClientSecretPresentationIssuer.prepare!(
      actor_context: context, token: token, issuance: issuance,
      step_up_evidence: evidence,
    )
    snapshot = issuance.reload.attributes

    assert_no_difference ["ClientSecretAuditOutbox.count", "ClientSecretCredential.count"] do
      assert_raises(ClientSecretManualIssuanceInvalidator::Denied) do
        ClientSecretManualIssuanceInvalidator.call_for_payload_failure!(
          actor_context: context, token: token, issuance: issuance, purge_after: 1.day,
          step_up_evidence: evidence.with(auth_time: evidence.auth_time - StepUpEvidenceValue::MAX_AGE_SECONDS),
        )
      end
    end
    assert_equal snapshot, issuance.reload.attributes
    assert_equal 1, issuance.reserved_count(at: Client.database_now)
  end

  test "audit failure rolls back cancellation candidate discard and payload removal" do
    actor = clients(:one)
    token = client_tokens(:one)
    evidence =
      begin
        now = ClientToken.database_now
        token.update!(root_login_established_at: now, established_authentication_method: "passkey")
        token.rotate_refresh_token!(now: now)
        token.device_session_record!
        oidc_client = OidcClientRegistry.find!("base-app-ww")
        grant = OpAppGrant.create!(
          authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
          oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
          oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
        )
        grant.issue_refresh_token!(now: now)
        StepUpEvidenceValue.new(
          acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
          sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
          aud: [oidc_client.aud], jti: grant.oidc_jti,
        )
      end
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )
    raw = SecureRandom.base58(32)
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Pending fixture", password: raw,
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
            step_up_evidence: evidence,
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
    evidence =
      begin
        now = ClientToken.database_now
        token.update!(root_login_established_at: now, established_authentication_method: "passkey")
        token.rotate_refresh_token!(now: now)
        token.device_session_record!
        oidc_client = OidcClientRegistry.find!("base-app-ww")
        grant = OpAppGrant.create!(
          authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
          oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
          oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
        )
        grant.issue_refresh_token!(now: now)
        StepUpEvidenceValue.new(
          acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
          sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
          aud: [oidc_client.aud], jti: grant.oidc_jti,
        )
      end
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    operation_id = SecureRandom.uuid
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: operation_id, expires_after: 1.minute,
      step_up_evidence: evidence,
    )
    assert_no_difference("ClientSecretCredential.count") do
      assert_difference("ClientSecretAuditOutbox.count", 1) do
        ClientSecretManualIssuanceInvalidator.call!(
          actor_context: context, token: token, issuance: issuance, purge_after: 1.day,
          step_up_evidence: evidence,
        )
      end
    end
    assert_no_difference("ClientSecretIssuance.count") do
      result = ClientSecretManualReservationIssuer.call!(
        actor_context: context, token: token, operation_id: operation_id, expires_after: 1.minute,
        step_up_evidence: evidence,
      )

      assert_equal :canceled, result.state(at: Client.database_now)
    end
    fresh = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )

    assert_equal :pending_presentation, fresh.state(at: Client.database_now)
    assert_equal 1, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
  end

  test "current owner and scoped Step-Up are required on cancellation and its replay" do
    actor = clients(:one)
    token = client_tokens(:one)
    evidence =
      begin
        now = ClientToken.database_now
        token.update!(root_login_established_at: now, established_authentication_method: "passkey")
        token.rotate_refresh_token!(now: now)
        token.device_session_record!
        oidc_client = OidcClientRegistry.find!("base-app-ww")
        grant = OpAppGrant.create!(
          authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
          oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
          oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
        )
        grant.issue_refresh_token!(now: now)
        StepUpEvidenceValue.new(
          acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
          sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
          aud: [oidc_client.aud], jti: grant.oidc_jti,
        )
      end
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )
    [
      nil,
      evidence.with(auth_time: evidence.auth_time - StepUpEvidenceValue::MAX_AGE_SECONDS),
      evidence.with(auth_time: evidence.auth_time + 1),
      evidence.with(sid: "foreign-grant"),
      evidence.with(sub: "foreign-subject"),
      evidence.with(client_id: "foreign-client"),
      evidence.with(aud: ["foreign-audience"]),
      evidence.with(acr: "urn:example:invalid-step-up"),
      evidence.with(amr: ["totp"]),
    ].each do |mismatch|
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ClientSecretManualIssuanceInvalidator::Denied) do
          ClientSecretManualIssuanceInvalidator.call!(
            actor_context: context, token: token, issuance: issuance, purge_after: 1.day,
            step_up_evidence: mismatch,
          )
        end
      end
      assert_nil issuance.reload.canceled_at
    end

    assert_difference("ClientSecretAuditOutbox.count", 1) do
      canceled = ClientSecretManualIssuanceInvalidator.call!(
        actor_context: context, token: token, issuance: issuance, purge_after: 1.day,
        step_up_evidence: evidence,
      )

      assert_equal :canceled, canceled.state(at: Client.database_now)
    end
    assert_no_difference("ClientSecretAuditOutbox.count") do
      replay = ClientSecretManualIssuanceInvalidator.call!(
        actor_context: context, token: token, issuance: issuance, purge_after: 2.days,
        step_up_evidence: evidence,
      )

      assert_equal :canceled, replay.state(at: Client.database_now)
    end
  end

  test "another owner or session cannot cancel a manual allocation" do
    actor = clients(:one)
    token = client_tokens(:one)
    evidence =
      begin
        now = ClientToken.database_now
        token.update!(root_login_established_at: now, established_authentication_method: "passkey")
        token.rotate_refresh_token!(now: now)
        token.device_session_record!
        oidc_client = OidcClientRegistry.find!("base-app-ww")
        grant = OpAppGrant.create!(
          authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
          oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
          oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
        )
        grant.issue_refresh_token!(now: now)
        StepUpEvidenceValue.new(
          acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
          sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
          aud: [oidc_client.aud], jti: grant.oidc_jti,
        )
      end
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
            step_up_evidence: evidence,
          )
        end
      end
      assert_nil issuance.reload.canceled_at
    end
  end

  test "expiry remains an expiry and confirmed or omitted allocations cannot be canceled" do
    actor = clients(:one)
    token = client_tokens(:one)
    evidence =
      begin
        now = ClientToken.database_now
        token.update!(root_login_established_at: now, established_authentication_method: "passkey")
        token.rotate_refresh_token!(now: now)
        token.device_session_record!
        oidc_client = OidcClientRegistry.find!("base-app-ww")
        grant = OpAppGrant.create!(
          authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
          oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
          oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
        )
        grant.issue_refresh_token!(now: now)
        StepUpEvidenceValue.new(
          acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
          sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
          aud: [oidc_client.aud], jti: grant.oidc_jti,
        )
      end
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
        step_up_evidence: evidence,
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
            step_up_evidence: evidence,
          )
        end
      end
      assert_nil terminal.reload.canceled_at
    end
  end

  test "ordinary model cancellation requires source audit and caller retention requires positive finite duration" do
    actor = clients(:one)
    token = client_tokens(:one)
    evidence =
      begin
        now = ClientToken.database_now
        token.update!(root_login_established_at: now, established_authentication_method: "passkey")
        token.rotate_refresh_token!(now: now)
        token.device_session_record!
        oidc_client = OidcClientRegistry.find!("base-app-ww")
        grant = OpAppGrant.create!(
          authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
          oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
          oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
        )
        grant.issue_refresh_token!(now: now)
        StepUpEvidenceValue.new(
          acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
          sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
          aud: [oidc_client.aud], jti: grant.oidc_jti,
        )
      end
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )

    assert_raises(ActiveRecord::RecordInvalid) { issuance.update!(canceled_at: Client.database_now) }
    assert_nil issuance.reload.canceled_at
    [nil, "", 0, [], {}, -1.second, 0.seconds, Float::INFINITY.seconds].each do |duration|
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ArgumentError) do
          ClientSecretManualIssuanceInvalidator.call!(
            actor_context: context, token: token, issuance: issuance, purge_after: duration,
            step_up_evidence: evidence,
          )
        end
      end
    end
    result = ClientSecretManualIssuanceInvalidator.call!(
      actor_context: context, token: token, issuance: issuance, purge_after: 0.000001.seconds,
      step_up_evidence: evidence,
    )

    assert_equal Rational(1, 1_000_000), result.purge_eligible_at.to_r - result.discard_at.to_r
  end
end
