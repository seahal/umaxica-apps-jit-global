# frozen_string_literal: true

require "test_helper"

class IdentityTotpNameCommitterTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  setup do
    @created_client_ids = []
  end

  teardown do
    token_ids = ClientToken.where(user_id: @created_client_ids).select(:id)
    OpAppGrant.where(client_token_id: token_ids).delete_all
    ClientTotpCredential.where(user_id: @created_client_ids).delete_all
    ClientDeviceSession.where(user_id: @created_client_ids).update_all(current_refresh_token_id: nil)
    ClientToken.where(user_id: @created_client_ids).delete_all
    ClientDeviceSession.where(user_id: @created_client_ids).delete_all
    ClientAuthorityLock.where(client_id: @created_client_ids).delete_all
    Client.where(id: @created_client_ids).delete_all
  end

  test "one current OP event renames multiple eligible TOTP credentials without target binding" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    first = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    second = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
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
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )

    commits = []
    subscriber =
      ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        payload = event.payload
        next unless payload[:name].to_s.include?("TRANSACTION") && payload[:sql].to_s.start_with?("COMMIT")

        commits << payload[:connection]&.pool&.db_config&.name
      end
    begin
      IdentityTotpNameCommitter.call!(
        actor:, token: nil, credential: first, title: "Phone authenticator",
        step_up_evidence: evidence,
      )
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
    IdentityTotpNameCommitter.call!(
      actor:, token:, credential: second, title: "Tablet authenticator",
      step_up_evidence: evidence,
    )

    principal_commit_index = commits.index("app_zenith")
    op_commit_index = commits.index("op_base_app")

    assert_not_nil principal_commit_index
    assert_not_nil op_commit_index
    assert_operator principal_commit_index, :<, op_commit_index,
                    "the Zenith rename must commit while the OP authorization transaction remains open"

    assert_equal "Phone authenticator", first.reload.title
    assert_equal "Tablet authenticator", second.reload.title
    OpBaseAppRecord.transaction do
      assert StepUpEvidenceVerifier.call(evidence:, actor:, token: token.reload)
    end
  end

  test "a superseded device token cannot authorize a TOTP rename" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
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
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    replacement = ClientToken.create!(authentication_epoch: 0, user: actor, device_session: device)
    device.update!(current_refresh_token_id: replacement.id)

    assert_raises(IdentityTotpNameCommitter::Denied) do
      IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "Denied", step_up_evidence: evidence)
    end
    assert_nil credential.reload.title
  end

  test "a revoked device cannot authorize a TOTP rename" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
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
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    token.device_session_record!.revoke!

    assert_raises(IdentityTotpNameCommitter::Denied) do
      IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "Denied", step_up_evidence: evidence)
    end
    assert_nil credential.reload.title
  end

  test "missing or foreign OP evidence cannot change a TOTP title" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    other_actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << other_actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )

    assert_raises(IdentityTotpNameCommitter::Denied) do
      IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "Missing")
    end
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    foreign_evidence = StepUpEvidenceValue.new(
      acr: StepUpEvidenceVerifier::STEP_UP_ACR, amr: ["passkey"], auth_time: ClientToken.database_now.to_i,
      sid: "foreign-grant", sub: OidcSubject.for(other_actor, resource_type: "client"),
      client_id: oidc_client.client_id, aud: [oidc_client.aud], jti: SecureRandom.uuid,
    )

    assert_raises(IdentityTotpNameCommitter::Denied) do
      IdentityTotpNameCommitter.call!(
        actor:, token:, credential:, title: "Foreign", step_up_evidence: foreign_evidence,
      )
    end
    assert_nil credential.reload.title
  end

  test "invalid names and foreign credentials do not change credentials or token state" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    foreign_actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << foreign_actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    original_token = token.reload.attributes

    assert_raises(IdentityTotpNameCommitter::InvalidTitle) do
      IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "x" * 33)
    end
    assert_raises(IdentityTotpNameCommitter::Denied) do
      IdentityTotpNameCommitter.call!(actor: foreign_actor, token:, credential:, title: "Foreign")
    end

    assert_equal original_token, token.reload.attributes
    assert_nil credential.reload.title
  end

  test "a Zenith write failure leaves the TOTP title unchanged and OP evidence reusable" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
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
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    failed = false
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless event.fetch(:sql).match?(/\A\s*UPDATE\s+"client_totp_credentials"/i)

        failed = true
        raise ActiveRecord::ConnectionNotEstablished, "injected Zenith write failure"
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      assert_raises(IdentityTotpNameCommitter::DependencyFailure) do
        IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "New title", step_up_evidence: evidence)
      end
    end

    assert failed
    assert_nil credential.reload.title
    OpBaseAppRecord.transaction do
      assert StepUpEvidenceVerifier.call(evidence:, actor:, token: token.reload)
    end
  end

  test "a Zenith commit failure leaves the old title and does not consume OP evidence" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
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
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    failed_commit = -> { raise ActiveRecord::ConnectionNotEstablished, "injected TOTP Zenith commit failure" }

    assert_raises(IdentityTotpNameCommitter::DependencyFailure) do
      Client.connection_class_for_self.lease_connection.stub(:commit_db_transaction, failed_commit) do
        IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "New title", step_up_evidence: evidence)
      end
    end

    assert_nil credential.reload.title
    OpBaseAppRecord.transaction do
      assert StepUpEvidenceVerifier.call(evidence:, actor:, token: token.reload)
    end
  end

  test "a confirmed Zenith rename stays successful when releasing the OP transaction fails" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
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
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    failed_commit = -> { raise ActiveRecord::ConnectionNotEstablished, "injected OP release failure" }

    result =
      OpBaseAppRecord.lease_connection.stub(:commit_db_transaction, failed_commit) do
        IdentityTotpNameCommitter.call!(
          actor:, token:, credential:, title: "Committed title", step_up_evidence: evidence,
        )
      end

    assert_equal "Committed title", result.reload.title
    assert_equal "Committed title", credential.reload.title
  end
end
