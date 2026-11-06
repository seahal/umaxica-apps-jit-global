# frozen_string_literal: true

require "test_helper"

# AC-P08: a changed description writes exactly one edit event; an identical value and authenticator
# maintenance write none, and the free text is not copied into the audit row.
class IdentityPasskeyNameCommitterTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []
  fixtures :client_token_binding_methods, :operator_token_binding_methods,
           :client_token_dbsc_statuses, :operator_token_dbsc_statuses,
           :client_token_kinds, :operator_token_kinds

  SURFACES = [
    [Client, ClientPasskey, ClientToken, ClientPasskeyAuditOutbox, :user_id, "app"],
    [Operator, OperatorPasskey, OperatorToken, OperatorPasskeyAuditOutbox, :staff_id, "org"],
  ].freeze

  setup do
    @actors = []
  end

  teardown do
    @actors.each do |actor|
      if actor.is_a?(Client)
        token_ids = ClientToken.where(user_id: actor.id).pluck(:id)
        OpAppGrant.where(client_token_id: token_ids).delete_all
        refs = ClientPasskey.where(user_id: actor.id).select(:external_id)
        ClientPasskeyAuditOutbox.where(external_id: refs).delete_all
        ClientPasskey.where(user_id: actor.id).delete_all
        ClientDeviceSession.where(user_id: actor.id).update_all(current_refresh_token_id: nil)
        ClientToken.where(user_id: actor.id).delete_all
        ClientDeviceSession.where(user_id: actor.id).delete_all
        ClientPreference.where(client_id: actor.id).destroy_all
        Client.where(id: actor.id).delete_all
      else
        token_ids = OperatorToken.where(staff_id: actor.id).pluck(:id)
        OpOrgGrant.where(operator_token_id: token_ids).delete_all
        refs = OperatorPasskey.where(staff_id: actor.id).select(:external_id)
        OperatorPasskeyAuditOutbox.where(external_id: refs).delete_all
        OperatorPasskey.where(staff_id: actor.id).delete_all
        OperatorDeviceSession.where(staff_id: actor.id).update_all(current_refresh_token_id: nil)
        OperatorToken.where(staff_id: actor.id).delete_all
        OperatorDeviceSession.where(staff_id: actor.id).delete_all
        OperatorPreference.where(operator_id: actor.id).destroy_all
        Operator.where(id: actor.id).delete_all
      end
    end
  end

  test "ORG Normal can rename with scoped proof while Standby cannot reuse equivalent proof" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    @actors << actor
    target = actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "target-key", description: "Original",
    )
    normal = OperatorToken.create!(authentication_epoch: 0, staff: actor, authentication_context: "normal")
    standby = OperatorToken.create!(authentication_epoch: 0, staff: actor, authentication_context: "standby")
    now = OperatorToken.database_now
    normal.device_session_record!
    normal.update!(root_login_established_at: now, established_authentication_method: "passkey")
    normal.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-org-ww")
    grant = OpOrgGrant.create!(
      authentication_epoch: normal.authentication_epoch, operator_token: normal,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "operator"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )

    IdentityPasskeyNameCommitter.call!(
      actor: actor, token: normal, passkey: target, description: "Normal",
      step_up_evidence: evidence,
    )

    assert_equal "Normal", target.reload.description
    assert_equal 1, OperatorPasskeyAuditOutbox.where(external_id: target.external_id).count
    assert_raises(IdentityPasskeyNameCommitter::Denied) do
      IdentityPasskeyNameCommitter.call!(
        actor: actor, token: standby, passkey: target, description: "Standby",
        step_up_evidence: evidence,
      )
    end
    assert_equal "Normal", target.reload.description
    assert_equal 1, OperatorPasskeyAuditOutbox.where(external_id: target.external_id).count
  end

  test "evidence from another session cannot rename the target on either surface" do
    SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      @actors << actor
      token = token_class.create!(:authentication_epoch => 0, owner_key => actor.id)
      metadata = (key_class == OperatorPasskey) ? {} : { uv_verified_at: Time.current }
      passkey = key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "target-key",
        :description => "Original", **metadata,
      )
      now = token_class.database_now
      token.device_session_record!
      token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      oidc_client_id = (surface == "app") ? "base-app-ww" : "base-org-ww"
      resource_type = (surface == "app") ? "client" : "operator"
      grant_class = (surface == "app") ? OpAppGrant : OpOrgGrant
      token_key = (surface == "app") ? :client_token : :operator_token
      oidc_client = OidcClientRegistry.find!(oidc_client_id)
      grant = grant_class.create!(
        :authentication_epoch => token.authentication_epoch, token_key => token,
        :oidc_client_id => oidc_client.client_id, :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid,
        :oidc_nonce => SecureRandom.hex(16), :oidc_auth_time => Time.at(now.to_i).utc,
        :oidc_acr => StepUpEvidenceResolver::STEP_UP_ACR, :oidc_amr => JSON.generate(["passkey"]),
        :refresh_token_expires_at => now + 1.hour,
      )
      grant.issue_refresh_token!(now:)
      StepUpEvidenceValue.new(
        acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
        sub: OidcSubject.for(actor, resource_type:), client_id: oidc_client.client_id,
        aud: [oidc_client.aud], jti: grant.oidc_jti,
      )
      other_token = token_class.create!(:authentication_epoch => 0, owner_key => actor.id)
      now = token_class.database_now
      other_token.device_session_record!
      other_token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      other_token.rotate_refresh_token!(now:)
      oidc_client_id = (surface == "app") ? "base-app-ww" : "base-org-ww"
      resource_type = (surface == "app") ? "client" : "operator"
      grant_class = (surface == "app") ? OpAppGrant : OpOrgGrant
      token_key = (surface == "app") ? :client_token : :operator_token
      oidc_client = OidcClientRegistry.find!(oidc_client_id)
      grant = grant_class.create!(
        :authentication_epoch => other_token.authentication_epoch, token_key => other_token,
        :oidc_client_id => oidc_client.client_id, :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid,
        :oidc_nonce => SecureRandom.hex(16), :oidc_auth_time => Time.at(now.to_i).utc,
        :oidc_acr => StepUpEvidenceResolver::STEP_UP_ACR, :oidc_amr => JSON.generate(["passkey"]),
        :refresh_token_expires_at => now + 1.hour,
      )
      grant.issue_refresh_token!(now:)
      other_evidence = StepUpEvidenceValue.new(
        acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
        sub: OidcSubject.for(actor, resource_type:), client_id: oidc_client.client_id,
        aud: [oidc_client.aud], jti: grant.oidc_jti,
      )

      assert_raises(IdentityPasskeyNameCommitter::Denied, surface) do
        IdentityPasskeyNameCommitter.call!(
          actor:, token:, passkey:, description: "Denied", step_up_evidence: other_evidence,
        )
      end
      assert_equal "Original", passkey.reload.description
      assert_equal 0, outbox_class.where(external_id: passkey.external_id).count
    end
  end

  test "missing Step-Up evidence cannot rename a Passkey on either surface" do
    SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      @actors << actor
      token = token_class.create!(:authentication_epoch => 0, owner_key => actor.id)
      metadata = (key_class == OperatorPasskey) ? {} : { uv_verified_at: Time.current }
      passkey = key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "target-key",
        :description => "Original", **metadata,
      )
      now = token_class.database_now
      token.device_session_record!
      token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      oidc_client_id = (surface == "app") ? "base-app-ww" : "base-org-ww"
      resource_type = (surface == "app") ? "client" : "operator"
      grant_class = (surface == "app") ? OpAppGrant : OpOrgGrant
      token_key = (surface == "app") ? :client_token : :operator_token
      oidc_client = OidcClientRegistry.find!(oidc_client_id)
      grant = grant_class.create!(
        :authentication_epoch => token.authentication_epoch, token_key => token,
        :oidc_client_id => oidc_client.client_id, :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid,
        :oidc_nonce => SecureRandom.hex(16), :oidc_auth_time => Time.at(now.to_i).utc,
        :oidc_acr => StepUpEvidenceResolver::STEP_UP_ACR, :oidc_amr => JSON.generate(["passkey"]),
        :refresh_token_expires_at => now + 1.hour,
      )
      grant.issue_refresh_token!(now:)
      StepUpEvidenceValue.new(
        acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
        sub: OidcSubject.for(actor, resource_type:), client_id: oidc_client.client_id,
        aud: [oidc_client.aud], jti: grant.oidc_jti,
      )

      assert_raises(IdentityPasskeyNameCommitter::Denied, surface) do
        IdentityPasskeyNameCommitter.call!(
          actor:, token:, passkey:, description: "Denied", step_up_evidence: nil,
        )
      end
      assert_equal "Original", passkey.reload.description
      assert_equal 0, outbox_class.where(external_id: passkey.external_id).count
    end
  end

  test "a changed description writes one edit event without copying the text on every surface" do
    SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      @actors << actor
      token = token_class.create!(:authentication_epoch => 0, owner_key => actor.id)
      metadata = (key_class == OperatorPasskey) ? {} : { uv_verified_at: Time.current }
      passkey = key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "target-key",
        :description => "Original", **metadata,
      )
      now = token_class.database_now
      token.device_session_record!
      token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      oidc_client_id = (surface == "app") ? "base-app-ww" : "base-org-ww"
      resource_type = (surface == "app") ? "client" : "operator"
      grant_class = (surface == "app") ? OpAppGrant : OpOrgGrant
      token_key = (surface == "app") ? :client_token : :operator_token
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

      IdentityPasskeyNameCommitter.call!(
        actor:, token:, passkey:, description: "Private laptop name", step_up_evidence: evidence,
      )

      events = outbox_class.where(external_id: passkey.external_id)

      assert_equal ["passkey.description_changed"], events.pluck(:event_type), surface
      assert_equal "Private laptop name", passkey.reload.description
      assert_not_includes events.first.metadata.to_json, "Private laptop name", surface
      assert_not_includes events.first.metadata.to_json, "Original", surface
    end
  end

  test "the current Step-Up event can authorize repeated protected operations" do
    SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      @actors << actor
      token = token_class.create!(:authentication_epoch => 0, owner_key => actor.id)
      metadata = (key_class == OperatorPasskey) ? {} : { uv_verified_at: Time.current }
      passkey = key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "target-key",
        :description => "Original", **metadata,
      )
      now = token_class.database_now
      token.device_session_record!
      token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      oidc_client_id = (surface == "app") ? "base-app-ww" : "base-org-ww"
      resource_type = (surface == "app") ? "client" : "operator"
      grant_class = (surface == "app") ? OpAppGrant : OpOrgGrant
      token_key = (surface == "app") ? :client_token : :operator_token
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

      IdentityPasskeyNameCommitter.call!(
        actor:, token:, passkey:, description: "First name", step_up_evidence: evidence,
      )

      IdentityPasskeyNameCommitter.call!(
        actor:, token: token.reload, passkey:, description: "Second name", step_up_evidence: evidence,
      )

      assert_equal "Second name", passkey.reload.description, surface
      assert_equal 2, outbox_class.where(external_id: passkey.external_id).count, surface
    end
  end

  test "an identical description writes no edit event on every surface" do
    SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      @actors << actor
      token = token_class.create!(:authentication_epoch => 0, owner_key => actor.id)
      metadata = (key_class == OperatorPasskey) ? {} : { uv_verified_at: Time.current }
      passkey = key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "target-key",
        :description => "Original", **metadata,
      )
      now = token_class.database_now
      token.device_session_record!
      token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      oidc_client_id = (surface == "app") ? "base-app-ww" : "base-org-ww"
      resource_type = (surface == "app") ? "client" : "operator"
      grant_class = (surface == "app") ? OpAppGrant : OpOrgGrant
      token_key = (surface == "app") ? :client_token : :operator_token
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

      IdentityPasskeyNameCommitter.call!(
        actor:, token:, passkey:, description: "Original", step_up_evidence: evidence,
      )

      assert_equal 0, outbox_class.where(external_id: passkey.external_id).count, surface
    end
  end

  test "authenticator maintenance writes no edit event on every surface" do
    SURFACES.each do |actor_class, key_class, _token_class, outbox_class, owner_key, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      @actors << actor
      metadata = (key_class == OperatorPasskey) ? {} : { uv_verified_at: Time.current }
      passkey = key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "target-key",
        :description => "Original", **metadata,
      )
      maintenance = { sign_count: passkey.sign_count + 1, last_used_at: Time.current }
      maintenance[:uv_verified_at] = Time.current unless key_class == OperatorPasskey

      passkey.update!(maintenance)

      assert_equal 0, outbox_class.where(external_id: passkey.external_id).count, surface
    end
  end

  [false, true].each do |savepoint|
    test "an outer OP transaction with savepoint #{savepoint} refuses rename on every surface" do
      SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
        actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
        @actors << actor
        token = token_class.create!(:authentication_epoch => 0, owner_key => actor.id)
        metadata = (key_class == OperatorPasskey) ? {} : { uv_verified_at: Time.current }
        passkey = key_class.create!(
          owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "target-key",
          :description => "Original", **metadata,
        )
        now = token_class.database_now
        token.device_session_record!
        token.update!(root_login_established_at: now, established_authentication_method: "passkey")
        token.rotate_refresh_token!(now:)
        oidc_client_id = (surface == "app") ? "base-app-ww" : "base-org-ww"
        resource_type = (surface == "app") ? "client" : "operator"
        grant_class = (surface == "app") ? OpAppGrant : OpOrgGrant
        token_key = (surface == "app") ? :client_token : :operator_token
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
        op_record = (surface == "app") ? OpBaseAppRecord : OpBaseOrgRecord

        op_record.transaction do
          op_record.transaction(requires_new: savepoint) do
            assert_raises(IdentityPasskeyNameCommitter::DependencyFailure, surface) do
              IdentityPasskeyNameCommitter.call!(
                actor:, token:, passkey:, description: "Changed", step_up_evidence: evidence,
              )
            end
          end
          raise ActiveRecord::Rollback
        end

        assert_equal "Original", passkey.reload.description, surface
        assert OpAppGrant.exists?(public_id: evidence.sid) if surface == "app"
        assert OpOrgGrant.exists?(public_id: evidence.sid) if surface == "org"

        assert_equal 0, outbox_class.where(external_id: passkey.external_id).count, surface
      end
    end
  end

  # A Zenith rename failure leaves the OP evidence event available and commits no source audit.
  test "a zenith-side failure leaves the Step-Up event reusable and keeps the name" do
    SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      @actors << actor
      token = token_class.create!(:authentication_epoch => 0, owner_key => actor.id)
      metadata = (key_class == OperatorPasskey) ? {} : { uv_verified_at: Time.current }
      passkey = key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "target-key",
        :description => "Original", **metadata,
      )
      now = token_class.database_now
      token.device_session_record!
      token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      oidc_client_id = (surface == "app") ? "base-app-ww" : "base-org-ww"
      resource_type = (surface == "app") ? "client" : "operator"
      grant_class = (surface == "app") ? OpAppGrant : OpOrgGrant
      token_key = (surface == "app") ? :client_token : :operator_token
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
      injected = ->(**_kwargs) { raise ActiveRecord::ConnectionNotEstablished, "injected audit failure" }

      PasskeyAuditOutbox.stub(:record_for!, injected) do
        assert_raises(IdentityPasskeyNameCommitter::DependencyFailure, surface) do
          IdentityPasskeyNameCommitter.call!(
            actor:, token:, passkey:, description: "Failed rename", step_up_evidence: evidence,
          )
        end
      end

      assert_equal "Original", passkey.reload.description, surface
      assert_equal 0, outbox_class.where(external_id: passkey.external_id).count, surface
      assert_predicate evidence.sid, :present?, "#{surface} Step-Up event remains reusable"
    end
  end

  test "an app Zenith commit failure keeps the old name and leaves the Step-Up event reusable" do
    actor = Client.create!(security_mode_id: SecurityModeTestDefault.id_for(Client))
    @actors << actor
    token = ClientToken.create!(authentication_epoch: 0, user_id: actor.id)
    target = ClientPasskey.create!(
      user_id: actor.id, webauthn_id: SecureRandom.uuid, public_key: "app-name-target",
      description: "Original", uv_verified_at: Time.current,
    )
    now = ClientToken.database_now
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
    failed_commit = -> { raise ActiveRecord::ConnectionNotEstablished, "injected app Zenith commit failure" }

    assert_raises(IdentityPasskeyNameCommitter::DependencyFailure) do
      AppZenithRecord.lease_connection.stub(:commit_db_transaction, failed_commit) do
        IdentityPasskeyNameCommitter.call!(
          actor: actor, token: token, passkey: target, description: "Changed",
          step_up_evidence: evidence,
        )
      end
    end

    assert_equal "Original", target.reload.description
    assert_equal 0, ClientPasskeyAuditOutbox.where(external_id: target.external_id).count
    assert OpAppGrant.exists?(public_id: evidence.sid)
  end

  test "an org Zenith commit failure keeps the old name and leaves the Step-Up event reusable" do
    actor = Operator.create!(security_mode_id: SecurityModeTestDefault.id_for(Operator))
    @actors << actor
    token = OperatorToken.create!(authentication_epoch: 0, staff_id: actor.id)
    target = OperatorPasskey.create!(
      staff_id: actor.id, webauthn_id: SecureRandom.uuid, public_key: "org-name-target", description: "Original",
    )
    now = OperatorToken.database_now
    token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-org-ww")
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch, operator_token: token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "operator"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    failed_commit = -> { raise ActiveRecord::ConnectionNotEstablished, "injected org Zenith commit failure" }

    assert_raises(IdentityPasskeyNameCommitter::DependencyFailure) do
      OrgZenithRecord.lease_connection.stub(:commit_db_transaction, failed_commit) do
        IdentityPasskeyNameCommitter.call!(
          actor: actor, token: token, passkey: target, description: "Changed",
          step_up_evidence: evidence,
        )
      end
    end

    assert_equal "Original", target.reload.description
    assert_equal 0, OperatorPasskeyAuditOutbox.where(external_id: target.external_id).count
    assert OpOrgGrant.exists?(public_id: evidence.sid)
  end

  test "a lost Zenith commit acknowledgement is confirmed by its durable receipt" do
    SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      @actors << actor
      token = token_class.create!(:authentication_epoch => 0, owner_key => actor.id)
      metadata = (key_class == OperatorPasskey) ? {} : { uv_verified_at: Time.current }
      passkey = key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "target-key",
        :description => "Original", **metadata,
      )
      now = token_class.database_now
      token.device_session_record!
      token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      oidc_client_id = (surface == "app") ? "base-app-ww" : "base-org-ww"
      resource_type = (surface == "app") ? "client" : "operator"
      grant_class = (surface == "app") ? OpAppGrant : OpOrgGrant
      token_key = (surface == "app") ? :client_token : :operator_token
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
      connection = (surface == "app") ? AppZenithRecord.lease_connection : OrgZenithRecord.lease_connection
      commit = connection.method(:commit_db_transaction)
      lose_acknowledgement =
        lambda do
          commit.call
          connection.disconnect!
          raise ActiveRecord::ConnectionNotEstablished, "injected lost #{surface} Zenith commit acknowledgement"
        end

      connection.stub(:commit_db_transaction, lose_acknowledgement) do
        connection.stub(:rollback_db_transaction, -> { }) do
          IdentityPasskeyNameCommitter.call!(
            actor:, token:, passkey:, description: "Committed despite lost acknowledgement",
            step_up_evidence: evidence,
          )
        end
      end

      assert_equal "Committed despite lost acknowledgement", key_class.find(passkey.id).description, surface
      assert_equal 1, outbox_class.where(external_id: passkey.external_id).count, surface
      assert_predicate evidence.sid, :present?, "#{surface} Step-Up event remains reusable"
    end
  end

  test "malformed Step-Up evidence reports denial and changes nothing" do
    SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
      actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
      @actors << actor
      token = token_class.create!(:authentication_epoch => 0, owner_key => actor.id)
      metadata = (key_class == OperatorPasskey) ? {} : { uv_verified_at: Time.current }
      passkey = key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "target-key",
        :description => "Original", **metadata,
      )
      now = token_class.database_now
      token.device_session_record!
      token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      oidc_client_id = (surface == "app") ? "base-app-ww" : "base-org-ww"
      resource_type = (surface == "app") ? "client" : "operator"
      grant_class = (surface == "app") ? OpAppGrant : OpOrgGrant
      token_key = (surface == "app") ? :client_token : :operator_token
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
      evidence = evidence.with(jti: SecureRandom.uuid)

      assert_raises(IdentityPasskeyNameCommitter::Denied, surface) do
        IdentityPasskeyNameCommitter.call!(
          actor:, token:, passkey:, description: "Malformed evidence", step_up_evidence: evidence,
        )
      end

      assert_equal "Original", passkey.reload.description, surface
      assert_equal 0, outbox_class.where(external_id: passkey.external_id).count, surface
      assert OpAppGrant.exists?(public_id: evidence.sid) if surface == "app"
      assert OpOrgGrant.exists?(public_id: evidence.sid) if surface == "org"
    end
  end
end
