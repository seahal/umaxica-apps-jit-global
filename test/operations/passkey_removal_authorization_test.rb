# frozen_string_literal: true

require "test_helper"

# Credential removal mutates Zenith only after an independently committed Ticket invalidation, so
# these authorization cases must run outside the fixture transaction.
class PasskeyRemovalAuthorizationTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false
  fixtures :client_token_binding_methods, :operator_token_binding_methods,
           :client_token_dbsc_statuses, :operator_token_dbsc_statuses

  setup do
    @created_clients = []
    @created_operators = []
  end

  teardown do
    client_ids = @created_clients.map(&:id)
    client_refs = @created_clients.map(&:public_id)
    operator_ids = @created_operators.map(&:id)
    operator_refs = @created_operators.map(&:public_id)

    if client_ids.any?
      client_token_ids = ClientToken.where(user_id: client_ids).pluck(:id)
      OpAppGrant.where(client_token_id: client_token_ids).delete_all
      ClientContactAuditOutbox.where(actor_ref: client_refs).delete_all
      ClientPasskeyAuditOutbox.where(actor_ref: client_refs).delete_all
      ClientTotpCredential.where(user_id: client_ids).delete_all
      ClientEmail.where(user_id: client_ids).delete_all
      ClientTelephone.where(user_id: client_ids).delete_all
      ClientPasskey.where(user_id: client_ids).delete_all
      ClientDeviceSession.where(user_id: client_ids).update_all(current_refresh_token_id: nil)
      ClientToken.where(user_id: client_ids).delete_all
      ClientDeviceSession.where(user_id: client_ids).delete_all
      ClientAuthorityLock.where(client_id: client_ids).delete_all
      ClientChronicle.where(subject_type: "Client", subject_id: client_ids.map(&:to_s)).delete_all
      Client.where(id: client_ids).delete_all
    end

    if operator_ids.any?
      operator_token_ids = OperatorToken.where(staff_id: operator_ids).pluck(:id)
      OpOrgGrant.where(operator_token_id: operator_token_ids).delete_all
      OperatorPasskeyAuditOutbox.where(actor_ref: operator_refs).delete_all
      OperatorPasskey.where(staff_id: operator_ids).delete_all
      OperatorDeviceSession.where(staff_id: operator_ids).update_all(current_refresh_token_id: nil)
      OperatorToken.where(staff_id: operator_ids).delete_all
      OperatorDeviceSession.where(staff_id: operator_ids).delete_all
      OperatorAuthorityLock.where(operator_id: operator_ids).delete_all
      OperatorChronicle.where(subject_type: "Operator", subject_id: operator_ids.map(&:to_s)).delete_all
      Operator.where(id: operator_ids).delete_all
    end
  end

  test "passkey removal requires scoped evidence in app and org even when another key survives" do
    [[Client, ClientPasskey, ClientToken, :user_id],
     [Operator, OperatorPasskey, OperatorToken, :staff_id],].each do |actor_class, key_class, token_class, owner_key|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      case actor
      when Client then @created_clients << actor
      when Operator then @created_operators << actor
      end
      token = token_class.create!(:authentication_epoch => 0, owner_key => actor.id)
      metadata = (key_class == OperatorPasskey) ? {} : { uv_verified_at: Time.current }
      key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid,
        :public_key => "surviving-key", **metadata,
      )
      target = key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid,
        :public_key => "target-key", **metadata,
      )
      status = target.status_id
      now = token.class.database_now
      token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      token.device_session_record!
      oidc_client_id = actor.is_a?(Client) ? "base-app-ww" : "base-org-ww"
      resource_type = actor.is_a?(Client) ? "client" : "operator"
      grant_class = actor.is_a?(Client) ? OpAppGrant : OpOrgGrant
      token_key = actor.is_a?(Client) ? :client_token : :operator_token
      oidc_client = OidcClientRegistry.find!(oidc_client_id)
      grant = grant_class.create!(
        :authentication_epoch => token.authentication_epoch, token_key => token,
        :oidc_client_id => oidc_client.client_id, :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid,
        :oidc_nonce => SecureRandom.hex(16), :oidc_auth_time => Time.at(now.to_i).utc,
        :oidc_acr => StepUpEvidenceResolver::STEP_UP_ACR, :oidc_amr => JSON.generate(["passkey"]),
        :refresh_token_expires_at => now + 1.hour,
      )
      grant.issue_refresh_token!(now:)
      evidence = StepUpEvidenceValue.new(
        acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
        sub: OidcSubject.for(actor, resource_type:), client_id: oidc_client.client_id,
        aud: [oidc_client.aud], jti: grant.oidc_jti,
      )

      assert_not IdentityCredentialRemovalCommitter.call!(
        actor: actor, credential: target, current_session: token, step_up_evidence: nil,
      ), "#{actor_class} must refuse missing step-up evidence"
      assert_equal status, target.reload.status_id
      assert_nil token.reload.last_step_up_at

      invalid_evidence = [
        evidence.with(auth_time: evidence.auth_time - StepUpEvidenceValue::MAX_AGE_SECONDS),
        evidence.with(auth_time: evidence.auth_time + 1),
        evidence.with(sid: "foreign-grant"),
        evidence.with(sub: "foreign-subject"),
        evidence.with(client_id: "foreign-client"),
        evidence.with(aud: ["foreign-audience"]),
        evidence.with(acr: "urn:example:invalid-step-up"),
        evidence.with(amr: ["totp"]),
      ]
      invalid_evidence.each do |candidate_evidence|
        assert_not IdentityCredentialRemovalCommitter.call!(
          actor: actor, credential: target, current_session: token, step_up_evidence: candidate_evidence,
        ), "#{actor_class} must refuse invalid Step-Up evidence"
        assert_equal status, target.reload.status_id
      end
    end
  end

  test "login-blocked owners cannot remove Passkeys with earlier Step-Up" do
    [
      [Client, ClientPasskey, ClientToken, ClientStatus::ACTIVE, ClientStatus::RESERVED, :user_id],
      [Operator, OperatorPasskey, OperatorToken, OperatorStatus::ACTIVE, OperatorStatus::RESERVED, :staff_id],
    ].each do |values|
      actor_class, key_class, token_class, active, blocked, owner_key = values
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class), status_id: active)
      case actor
      when Client then @created_clients << actor
      when Operator then @created_operators << actor
      end
      metadata = (key_class == ClientPasskey) ? { uv_verified_at: Time.current } : {}
      key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "remaining", **metadata,
      )
      target = key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "target", **metadata,
      )
      token = token_class.create!(:authentication_epoch => 0, owner_key => actor.id)
      now = token.class.database_now
      token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      token.device_session_record!
      oidc_client_id = actor.is_a?(Client) ? "base-app-ww" : "base-org-ww"
      resource_type = actor.is_a?(Client) ? "client" : "operator"
      grant_class = actor.is_a?(Client) ? OpAppGrant : OpOrgGrant
      token_key = actor.is_a?(Client) ? :client_token : :operator_token
      oidc_client = OidcClientRegistry.find!(oidc_client_id)
      grant = grant_class.create!(
        :authentication_epoch => token.authentication_epoch, token_key => token,
        :oidc_client_id => oidc_client.client_id, :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid,
        :oidc_nonce => SecureRandom.hex(16), :oidc_auth_time => Time.at(now.to_i).utc,
        :oidc_acr => StepUpEvidenceResolver::STEP_UP_ACR, :oidc_amr => JSON.generate(["passkey"]),
        :refresh_token_expires_at => now + 1.hour,
      )
      grant.issue_refresh_token!(now:)
      evidence = StepUpEvidenceValue.new(
        acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
        sub: OidcSubject.for(actor, resource_type:), client_id: oidc_client.client_id,
        aud: [oidc_client.aud], jti: grant.oidc_jti,
      )
      actor.reload.update!(status_id: blocked)

      assert_not IdentityCredentialRemovalCommitter.call!(
        actor: actor, credential: target, current_session: token,
        step_up_evidence: evidence,
      )
      assert_predicate target.reload, :persisted?
      assert_nil token.reload.last_step_up_at
    end
  end
end
