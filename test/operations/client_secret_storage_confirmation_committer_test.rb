# frozen_string_literal: true

require "test_helper"

class ClientSecretStorageConfirmationCommitterTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @created_client_ids = []
  end

  teardown do
    next if Array(@created_client_ids).empty?

    actor_refs = Client.where(id: @created_client_ids).pluck(:public_id)
    ClientSecretAuditOutbox.where(client_ref: actor_refs).delete_all
    ClientSecretCredential.where(client_id: @created_client_ids).delete_all
    ClientSecretIssuance.where(client_id: @created_client_ids).delete_all
    OpAppGrant.where(client_token_id: ClientToken.where(user_id: @created_client_ids)).delete_all
    ClientDeviceSession.where(user_id: @created_client_ids).update_all(current_refresh_token_id: nil)
    ClientToken.where(user_id: @created_client_ids).delete_all
    ClientDeviceSession.where(user_id: @created_client_ids).delete_all
    ClientAuthorityLock.where(client_id: @created_client_ids).delete_all
    ClientPreference.where(client_id: @created_client_ids).destroy_all
    Client.where(id: @created_client_ids).delete_all
  end

  test "a superseded device token cannot authorize Secret storage confirmation" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    device = token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Storage target", password: SecureRandom.base58(32),
    )
    at = Client.database_now
    ClientSecretAuditOutbox.transaction do
      issuance.update!(presented_at: at)
      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
        operation_ref: issuance.origin_operation_id, occurred_at: at, event_name: "secret.presented", item_count: 1,
      )
    end
    replacement = ClientToken.create!(authentication_epoch: 0, user: actor, device_session: device)
    device.update!(current_refresh_token_id: replacement.id)

    assert_raises(ClientSecretStorageConfirmationCommitter::Denied) do
      ClientSecretStorageConfirmationCommitter.call!(
        actor_context: context, token: token, issuance: issuance,
        step_up_evidence: evidence,
      )
    end
    assert_nil issuance.reload.confirmed_at
    assert_nil candidate.reload.confirmed_at
    assert_predicate grant.reload, :persisted?
  end

  test "a revoked device cannot authorize Secret storage confirmation" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Storage target", password: SecureRandom.base58(32),
    )
    at = Client.database_now
    ClientSecretAuditOutbox.transaction do
      issuance.update!(presented_at: at)
      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
        operation_ref: issuance.origin_operation_id, occurred_at: at, event_name: "secret.presented", item_count: 1,
      )
    end
    token.device_session_record!.revoke!

    assert_raises(ClientSecretStorageConfirmationCommitter::Denied) do
      ClientSecretStorageConfirmationCommitter.call!(
        actor_context: context, token: token, issuance: issuance,
        step_up_evidence: evidence,
      )
    end
    assert_nil issuance.reload.confirmed_at
    assert_nil candidate.reload.confirmed_at
    assert_predicate grant.reload, :persisted?
  end

  test "an enclosing OP transaction is refused before evidence or source writes" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor, established_authentication_method: "secret")
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Enclosing target", password: SecureRandom.base58(32),
    )
    ClientSecretIssuance.transaction do
      at = Client.database_now
      issuance.update!(presented_at: at)
      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
        operation_ref: issuance.origin_operation_id, occurred_at: at, event_name: "secret.presented", item_count: 1,
      )
    end
    token_state = token.reload.attributes

    OpBaseAppRecord.transaction(joinable: false) do
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ClientSecretStorageConfirmationCommitter::TransactionConflict) do
          ClientSecretStorageConfirmationCommitter.call!(
            actor_context: context, token: token, issuance: issuance,
            step_up_evidence: evidence,
          )
        end
      end
    end

    assert_nil issuance.reload.confirmed_at
    assert_nil candidate.reload.confirmed_at
    assert_equal token_state, token.reload.attributes
  end

  test "a current step-up event authorizes confirmation regardless of the root login method" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(
      authentication_epoch: 0, user: actor, established_authentication_method: "secret",
    )
    now = ClientToken.database_now
    token.update!(root_login_established_at: now)
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretIssuance.create!(
      client: actor, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
      planned_count: 1, browser_session_ref: token.public_id, expires_at: now + 1.minute, presented_at: now,
    )
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Presented value", password: SecureRandom.base58(32),
    )
    ClientSecretAuditOutbox.transaction do
      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
        operation_ref: issuance.origin_operation_id, occurred_at: now, event_name: "secret.presented", item_count: 1,
      )
    end

    ClientSecretStorageConfirmationCommitter.call!(
      actor_context: context, token: token, issuance: issuance, step_up_evidence: evidence,
    )

    assert_equal :confirmed, issuance.reload.state(at: Client.database_now)
    assert_equal "secret", token.reload.established_authentication_method
  end

  test "the current Step-Up event confirms a presentation and remains reusable for an exact retry" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor, established_authentication_method: "secret")
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: evidence,
    )
    raw = SecureRandom.base58(32)
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Stored value", password: raw,
    )
    # Prepare completed presentation facts; this test does not deliver plaintext.
    ClientSecretIssuance.transaction do
      at = Client.database_now
      issuance.update!(presented_at: at)
      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
        operation_ref: issuance.origin_operation_id, occurred_at: at, event_name: "secret.presented", item_count: 1,
      )
    end
    token_state = token.reload.attributes
    assert_difference("ClientSecretAuditOutbox.count", 2) do
      ClientSecretStorageConfirmationCommitter.call!(
        actor_context: context, token: token, issuance: issuance,
        step_up_evidence: evidence,
      )
    end

    assert_equal token_state, token.reload.attributes
    assert_equal :confirmed, issuance.reload.state(at: Client.database_now)
    assert_equal issuance.confirmed_at, candidate.reload.confirmed_at
    assert_equal candidate.id, ClientSecretLookupQuery.call(client: actor, secret: raw).id
    counts = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)

    assert_equal 1, counts.active_count
    assert_equal 0, counts.reserved_count
    confirmed_at = issuance.confirmed_at
    assert_no_difference("ClientSecretAuditOutbox.count") do
      assert_equal issuance.id, ClientSecretStorageConfirmationCommitter.call!(
        actor_context: context, token: token, issuance: issuance,
        step_up_evidence: evidence,
      ).id
    end
    no_op_token = token.reload.attributes
    %w(secret.storage_declared secret.created).each do |event_name|
      ClientSecretAuditOutbox.transaction(requires_new: true) do
        ClientSecretAuditOutbox.where(
          operation_ref: issuance.origin_operation_id, event_name: event_name,
        ).delete_all
        assert_raises(ClientSecretStorageConfirmationCommitter::InvalidState) do
          ClientSecretStorageConfirmationCommitter.call!(
            actor_context: context, token: token, issuance: issuance,
            step_up_evidence: evidence,
          )
        end
        assert_equal no_op_token, token.reload.attributes
        raise ActiveRecord::Rollback
      end
    end
    assert_no_difference("ClientSecretAuditOutbox.count") do
      ClientSecretStorageConfirmationCommitter.call!(
        actor_context: context, token: token, issuance: issuance,
        step_up_evidence: evidence,
      )
    end
    assert_equal confirmed_at, issuance.reload.confirmed_at
    assert_equal no_op_token, token.reload.attributes

    assert_raises(ActiveRecord::ReadonlyAttributeError) { candidate.update!(confirmed_at: nil) }
    assert_raises(ActiveRecord::ActiveRecordError) { candidate.update_columns(confirmed_at: nil) }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { candidate.write_attribute(:confirmed_at, nil) }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { candidate.touch(:confirmed_at) }
    [nil, confirmed_at - Rational(1, 1_000_000), confirmed_at + Rational(1, 1_000_000)].each do |replacement|
      assert_raises(ActiveRecord::ReadonlyAttributeError) { candidate.reload[:confirmed_at] = replacement }
      assert_equal confirmed_at, candidate.reload.confirmed_at
    end
  end

  test "the exact two presented candidates confirm together and source audit failure rolls back the whole batch" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    now = ClientToken.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    at = Client.database_now
    issuance = ClientSecretIssuance.create!(
      client: actor, origin_operation_id: SecureRandom.uuid, origin: "passkey_registration", attempt_number: 1,
      planned_count: 2, browser_session_ref: token.public_id, expires_at: at + 1.minute, presented_at: at,
    )
    # Prepare presentation evidence; registration and plaintext delivery are outside this boundary.
    candidates =
      2.times.map do |index|
        raw = SecureRandom.base58(32)
        ClientSecretCredential.create!(
          client: actor, issuance: issuance, name: "Batch item #{index}", password: raw,
        )
      end
    ClientSecretAuditOutbox.transaction do
      candidates.each do |candidate|
        ClientSecretAuditOutbox.record!(
          actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
          operation_ref: issuance.origin_operation_id, occurred_at: at, event_name: "secret.presented", item_count: 1,
        )
      end
    end
    ids = [SecureRandom.uuid, SecureRandom.uuid, "invalid-event-id"]
    assert_no_difference("ClientSecretAuditOutbox.count") do
      SecureRandom.stub(:uuid, -> { ids.shift }) do
        assert_raises(ActiveRecord::RecordInvalid) do
          ClientSecretStorageConfirmationCommitter.call!(
            actor_context: context, token: token, issuance: issuance,
            step_up_evidence: evidence,
          )
        end
      end
    end
    assert_nil issuance.reload.confirmed_at
    candidates.each { |candidate| assert_nil candidate.reload.confirmed_at }
    counts = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)

    assert_equal 0, counts.active_count
    assert_equal 2, counts.reserved_count
    assert_nil grant.reload.revoked_at
    assert_difference("ClientSecretAuditOutbox.count", 3) do
      ClientSecretStorageConfirmationCommitter.call!(
        actor_context: context, token: token, issuance: issuance,
        step_up_evidence: evidence,
      )
    end
    candidates.each { |candidate| assert_equal issuance.reload.confirmed_at, candidate.reload.confirmed_at }
    counts = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)

    assert_equal 2, counts.active_count
    assert_equal 0, counts.reserved_count
  end

  test "confirmation refuses invalid event binding live session and presentation evidence" do
    %i(no_evidence wrong_audience wrong_session wrong_owner expired_evidence revoked restricted
       unpresented unaudited mismatched_presented extra_candidate).each do |scenario|
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      @created_client_ids << actor.id
      token = ClientToken.create!(authentication_epoch: 0, user: actor)
      now = ClientToken.database_now
      token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      token.device_session_record!
      oidc_client = OidcClientRegistry.find!("base-app-ww")
      grant = OpAppGrant.create!(
        authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
        oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
        oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
        oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
      )
      grant.issue_refresh_token!(now:)
      evidence = StepUpEvidenceValue.new(
        acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
        sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
        aud: [oidc_client.aud], jti: grant.oidc_jti,
      )
      context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
      issuance = ClientSecretManualReservationIssuer.call!(
        actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
        step_up_evidence: evidence,
      )
      raw = SecureRandom.base58(32)
      candidate = ClientSecretCredential.create!(
        client: actor, issuance: issuance, name: "Pending value", password: raw,
      )
      ClientSecretIssuance.transaction do
        at = Client.database_now
        issuance.update!(presented_at: at) unless scenario == :unpresented
        unless scenario == :unaudited
          ClientSecretAuditOutbox.record!(
            actor_context: context, client_ref: actor.public_id,
            credential_ref: ((scenario == :mismatched_presented) ? "N" * 21 : candidate.public_id),
            operation_ref: issuance.origin_operation_id, occurred_at: at, event_name: "secret.presented", item_count: 1,
          )
        end
      end
      supplied_evidence = evidence
      case scenario
      when :no_evidence then supplied_evidence = nil
      when :wrong_audience then supplied_evidence = evidence.with(aud: ["wrong-audience"])
      when :wrong_session then token = ClientToken.create!(authentication_epoch: 0, user: actor)
      when :wrong_owner
        other_actor = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
        )
        @created_client_ids << other_actor.id
        context = context.with(subject: other_actor)
      when :expired_evidence
        supplied_evidence = evidence.with(auth_time: evidence.auth_time - StepUpEvidenceValue::MAX_AGE_SECONDS - 1)
      when :revoked then token.update!(discard_at: ClientToken.database_now)
      when :restricted then token.update!(user_token_status_id: ClientTokenStatus::RESTRICTED)
      when :extra_candidate
        extra = SecureRandom.base58(32)
        ClientSecretCredential.create!(
          client: actor, issuance: issuance, name: "Unpresented addition", password: extra,
        )
      end
      failure =
        %i(unaudited mismatched_presented extra_candidate).include?(scenario) ?
          ClientSecretStorageConfirmationCommitter::InvalidState :
          ClientSecretStorageConfirmationCommitter::Denied
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(failure, "scenario #{scenario}") do
          ClientSecretStorageConfirmationCommitter.call!(
            actor_context: context, token: token, issuance: issuance,
            step_up_evidence: supplied_evidence,
          )
        end
      end
      assert_nil issuance.reload.confirmed_at
      assert_nil candidate.reload.confirmed_at
      assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
    end
  end

  [-1, 0, 1].each do |offset|
    test "confirmation evaluates issuance expiry #{offset} microseconds from its boundary" do
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      @created_client_ids << actor.id
      token = ClientToken.create!(authentication_epoch: 0, user: actor)
      now = ClientToken.database_now
      token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      token.device_session_record!
      oidc_client = OidcClientRegistry.find!("base-app-ww")
      grant = OpAppGrant.create!(
        authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
        oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
        oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
        oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
      )
      grant.issue_refresh_token!(now:)
      evidence = StepUpEvidenceValue.new(
        acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
        sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
        aud: [oidc_client.aud], jti: grant.oidc_jti,
      )
      context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
      issuance = ClientSecretManualReservationIssuer.call!(
        actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
        step_up_evidence: evidence,
      )
      raw = SecureRandom.base58(32)
      candidate = ClientSecretCredential.create!(
        client: actor, issuance: issuance, name: "Boundary value", password: raw,
      )
      ClientSecretAuditOutbox.transaction do
        at = Client.database_now
        issuance.update!(presented_at: at)
        ClientSecretAuditOutbox.record!(
          actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
          operation_ref: issuance.origin_operation_id, occurred_at: at, event_name: "secret.presented", item_count: 1,
        )
      end
      decision_at = issuance.expires_at + Rational(offset, 1_000_000)
      Client.stub(:database_now, decision_at) do
        if offset.negative?
          ClientSecretStorageConfirmationCommitter.call!(
            actor_context: context, token: token, issuance: issuance,
            step_up_evidence: evidence,
          )

          assert_equal decision_at, issuance.reload.confirmed_at
          assert_equal decision_at, candidate.reload.confirmed_at
        else
          assert_no_difference("ClientSecretAuditOutbox.count") do
            assert_raises(ClientSecretStorageConfirmationCommitter::Denied) do
              ClientSecretStorageConfirmationCommitter.call!(
                actor_context: context, token: token, issuance: issuance,
                step_up_evidence: evidence,
              )
            end
          end
          assert_nil issuance.reload.confirmed_at
          assert_nil candidate.reload.confirmed_at
        end
      end
    end
  end
end
