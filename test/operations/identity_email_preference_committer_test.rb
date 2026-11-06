# frozen_string_literal: true

require "test_helper"

class IdentityEmailPreferenceCommitterTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  setup do
    @created_client_ids = []
    @created_op_grant_ids = []
  end

  teardown do
    next if @created_client_ids.empty?

    actor_refs = Client.where(id: @created_client_ids).pluck(:public_id)
    ClientContactAuditOutbox.where(owner_ref: actor_refs).delete_all
    ClientEmail.where(user_id: @created_client_ids).delete_all
    OpAppGrant.where(id: @created_op_grant_ids).delete_all
    ClientDeviceSession.where(user_id: @created_client_ids).update_all(current_refresh_token_id: nil)
    ClientToken.where(user_id: @created_client_ids).delete_all
    ClientDeviceSession.where(user_id: @created_client_ids).delete_all
    ClientAuthorityLock.where(client_id: @created_client_ids).delete_all
    ClientPreference.where(client_id: @created_client_ids).destroy_all
    Client.where(id: @created_client_ids).delete_all
  end

  test "an enclosing OP transaction is refused before any evidence or preference write" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    email = ClientEmail.create!(
      user: actor, address: "transaction-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    now = OpBaseAppRecord.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    @created_op_grant_ids << grant.id
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    token_state = token.reload.attributes

    OpBaseAppRecord.transaction do
      assert_raises(IdentityEmailPreferenceCommitter::TransactionConflict) do
        IdentityEmailPreferenceCommitter.call!(
          actor:, token:, email:, preferences: { "promotional" => "0" }, step_up_evidence: evidence,
        )
      end
    end

    assert_predicate email.reload, :promotional?
    assert_equal token_state, token.reload.attributes
  end

  test "one current OP event authorizes preferences on distinct eligible emails" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    first = ClientEmail.create!(
      user: actor, address: "first-target-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    first.finalize_binding!
    now = OpBaseAppRecord.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    @created_op_grant_ids << grant.id
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )

    IdentityEmailPreferenceCommitter.call!(
      actor:, token:, email: first, preferences: { "promotional" => "0" }, step_up_evidence: evidence,
    )
    IdentityEmailPreferenceCommitter.call!(
      actor:, token:, email: first, preferences: { "notifiable" => "0" }, step_up_evidence: evidence,
    )

    assert_not first.reload.promotional?
    assert_not first.reload.notifiable?
    OpBaseAppRecord.transaction do
      assert StepUpEvidenceVerifier.call(evidence:, actor:, token: token.reload)
    end
  end

  test "a superseded device token cannot authorize an Email preference change" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    email = ClientEmail.create!(
      user: actor, address: "superseded-device-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    now = OpBaseAppRecord.database_now
    device = token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    @created_op_grant_ids << grant.id
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    replacement = ClientToken.create!(authentication_epoch: 0, user: actor, device_session: device)
    device.update!(current_refresh_token_id: replacement.id)

    assert_raises(IdentityEmailPreferenceCommitter::Denied) do
      IdentityEmailPreferenceCommitter.call!(
        actor:, token:, email:, preferences: { "promotional" => "0" }, step_up_evidence: evidence,
      )
    end
    assert_predicate email.reload, :promotional?
  end

  test "a revoked device cannot authorize an Email preference change" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    email = ClientEmail.create!(
      user: actor, address: "revoked-device-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    now = OpBaseAppRecord.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    @created_op_grant_ids << grant.id
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    token.device_session_record!.revoke!

    assert_raises(IdentityEmailPreferenceCommitter::Denied) do
      IdentityEmailPreferenceCommitter.call!(
        actor:, token:, email:, preferences: { "promotional" => "0" }, step_up_evidence: evidence,
      )
    end
    assert_predicate email.reload, :promotional?
  end

  test "refused OP evidence leaves the email preference unchanged" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    email = ClientEmail.create!(
      user: actor, address: "ordering-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    now = OpBaseAppRecord.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    @created_op_grant_ids << grant.id
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    token_state = token.reload.attributes

    StepUpEvidenceVerifier.stub(:call, false) do
      assert_raises(IdentityEmailPreferenceCommitter::Denied) do
        IdentityEmailPreferenceCommitter.call!(
          actor:, token:, email:, preferences: { "promotional" => "0" }, step_up_evidence: evidence,
        )
      end
    end

    assert_predicate email.reload, :promotional?
    assert_equal token_state, token.reload.attributes
  end

  test "a Zenith write failure keeps the email unchanged and leaves OP evidence reusable" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    email = ClientEmail.create!(
      user: actor, address: "write-failure-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    now = OpBaseAppRecord.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    @created_op_grant_ids << grant.id
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    failed = false
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless event.fetch(:sql).match?(/\A\s*UPDATE\s+"client_emails"/i)

        failed = true
        raise ActiveRecord::ConnectionNotEstablished, "injected Zenith write failure"
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      assert_raises(IdentityEmailPreferenceCommitter::DependencyFailure) do
        IdentityEmailPreferenceCommitter.call!(
          actor:, token:, email:, preferences: { "promotional" => "0" }, step_up_evidence: evidence,
        )
      end
    end

    assert failed
    assert_predicate email.reload, :promotional?
    assert IdentityEmailPreferenceCommitter.call!(
      actor:, token:, email:, preferences: { "promotional" => "0" }, step_up_evidence: evidence,
    )
    assert_not email.reload.promotional?
  end

  test "a changed preference reuses its OP evidence and a no-op leaves token state unchanged" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    email = ClientEmail.create!(
      user: actor, address: "preferences-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    now = OpBaseAppRecord.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    @created_op_grant_ids << grant.id
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )

    IdentityEmailPreferenceCommitter.call!(
      actor:, token:, email:, preferences: { "promotional" => "0", "notifiable" => "1" },
      step_up_evidence: evidence,
    )

    assert_not email.reload.promotional?
    assert_predicate email, :notifiable?
    IdentityEmailPreferenceCommitter.call!(
      actor:, token:, email:, preferences: { "promotional" => "1" }, step_up_evidence: evidence,
    )

    assert_predicate email.reload, :promotional?
    token_state = token.reload.attributes
    IdentityEmailPreferenceCommitter.call!(
      actor:, token:, email:, preferences: { "promotional" => "1", "notifiable" => "1" },
      step_up_evidence: evidence,
    )

    assert_equal token_state, token.reload.attributes
  end

  test "a changed Email preference writes one reference-only Source audit" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    email = ClientEmail.create!(
      user: actor, address: "audit-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    now = OpBaseAppRecord.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    @created_op_grant_ids << grant.id
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )

    assert_difference -> {
      ClientContactAuditOutbox.where(
        event_name: "preferences_changed", owner_ref: actor.public_id, contact_ref: email.public_id,
      ).count
    }, 1 do
      IdentityEmailPreferenceCommitter.call!(
        actor:, token:, email:, preferences: { "promotional" => "0" }, step_up_evidence: evidence,
      )
    end

    audit = ClientContactAuditOutbox.find_by!(
      event_name: "preferences_changed", owner_ref: actor.public_id, contact_ref: email.public_id,
    )

    assert_equal "email", audit.contact_kind
    assert_equal actor.public_id, audit.actor_ref
    assert_match(/\A[0-9a-f-]{36}\z/, audit.operation_ref)
    assert_not audit.attributes.key?("address")
    assert_not audit.attributes.key?("promotional")
    assert_not audit.attributes.key?("notifiable")
  end

  test "an audit outbox failure rolls back the Email setting without consuming OP evidence" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    email = ClientEmail.create!(
      user: actor, address: "audit-failure-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    now = OpBaseAppRecord.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    @created_op_grant_ids << grant.id
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    token_state = token.reload.attributes
    failed = false
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless event.fetch(:sql).match?(/\A\s*INSERT INTO "client_contact_audit_outboxes"/i)

        failed = true
        raise ActiveRecord::ConnectionNotEstablished, "injected Source audit failure"
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      assert_raises(IdentityEmailPreferenceCommitter::DependencyFailure) do
        IdentityEmailPreferenceCommitter.call!(
          actor:, token:, email:, preferences: { "promotional" => "0" }, step_up_evidence: evidence,
        )
      end
    end

    assert failed
    assert_predicate email.reload, :promotional?
    assert_equal token_state, token.reload.attributes
    assert_equal 0, ClientContactAuditOutbox.where(
      event_name: "preferences_changed", owner_ref: actor.public_id, contact_ref: email.public_id,
    ).count
  end

  test "locked preferences, unsupported keys and a foreign email retain evidence" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    email = ClientEmail.create!(
      user: actor, address: "locked-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    now = OpBaseAppRecord.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    @created_op_grant_ids << grant.id
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    email.update!(user_email_status_id: ClientEmailStatus::UNVERIFIED)
    original = [email.reload.promotional, email.notifiable]
    token_state = token.reload.attributes

    IdentityEmailPreferenceCommitter.call!(
      actor:, token:, email:, preferences: { "promotional" => "0", "notifiable" => "0" },
      step_up_evidence: evidence,
    )

    assert_equal original, [email.reload.promotional, email.notifiable]
    assert_equal token_state, token.reload.attributes
    assert_raises(ArgumentError) do
      IdentityEmailPreferenceCommitter.call!(
        actor:, token:, email:, preferences: { "unexpected" => "x" }, step_up_evidence: evidence,
      )
    end
    foreign_actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << foreign_actor.id
    foreign_email = ClientEmail.create!(
      user: foreign_actor, address: "foreign-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    foreign_email.finalize_binding!

    assert_raises(IdentityEmailPreferenceCommitter::Denied) do
      IdentityEmailPreferenceCommitter.call!(
        actor: foreign_actor, token:, email: foreign_email, preferences: { "promotional" => "0" },
        step_up_evidence: evidence,
      )
    end
    assert_equal token_state, token.reload.attributes
  end
end
