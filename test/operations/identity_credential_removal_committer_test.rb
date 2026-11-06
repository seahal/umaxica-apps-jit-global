# frozen_string_literal: true

require "test_helper"

class IdentityCredentialRemovalCommitterTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

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
      OpAppGrant.where(client_token_id: ClientToken.where(user_id: client_ids).select(:id)).delete_all
      ClientContactAuditOutbox.where(actor_ref: client_refs).delete_all
      ClientPasskeyAuditOutbox.where(actor_ref: client_refs).delete_all
      client_tokens = ClientToken.where(user_id: client_ids).select(:id)
      ClientStepUpSession.where(user_token_id: client_tokens).delete_all
      client_parents = ClientStepUpCeremonyTransaction.where(actor_ref: client_refs)
      ClientAuthCeremonySession.where(
        step_up_ceremony_transaction_ref: client_parents.select(:transaction_id),
      ).delete_all
      client_parents.delete_all
      ClientTotpCredential.where(user_id: client_ids).delete_all
      ClientEmail.where(user_id: client_ids).delete_all
      ClientTelephone.where(user_id: client_ids).delete_all
      ClientPasskey.where(user_id: client_ids).delete_all
      ClientDeviceSession.where(user_id: client_ids).update_all(current_refresh_token_id: nil)
      ClientToken.where(user_id: client_ids).delete_all
      ClientDeviceSession.where(user_id: client_ids).delete_all
      ClientAuthorityLock.where(client_id: client_ids).delete_all
      ClientChronicle.where(subject_type: "Client", subject_id: client_ids.map(&:to_s)).delete_all
      ClientPreference.where(client_id: client_ids).destroy_all
      Client.where(id: client_ids).delete_all
    end

    if operator_ids.any?
      OpOrgGrant.where(operator_token_id: OperatorToken.where(staff_id: operator_ids).select(:id)).delete_all
      OperatorPasskeyAuditOutbox.where(actor_ref: operator_refs).delete_all
      operator_tokens = OperatorToken.where(staff_id: operator_ids).select(:id)
      OperatorStepUpSession.where(staff_token_id: operator_tokens).delete_all
      operator_parents = OperatorStepUpCeremonyTransaction.where(actor_ref: operator_refs)
      OperatorAuthCeremonySession.where(
        step_up_ceremony_transaction_ref: operator_parents.select(:transaction_id),
      ).delete_all
      operator_parents.delete_all
      OperatorPasskey.where(staff_id: operator_ids).delete_all
      OperatorDeviceSession.where(staff_id: operator_ids).update_all(current_refresh_token_id: nil)
      OperatorToken.where(staff_id: operator_ids).delete_all
      OperatorDeviceSession.where(staff_id: operator_ids).delete_all
      OperatorAuthorityLock.where(operator_id: operator_ids).delete_all
      OperatorChronicle.where(subject_type: "Operator", subject_id: operator_ids.map(&:to_s)).delete_all
      Operator.where(id: operator_ids).delete_all
    end
  end

  test "a non-joinable outer OP transaction is refused before credential removal" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_clients << actor
    credential = actor.client_totp_credentials.create!(
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)

    OpBaseAppRecord.transaction(joinable: false) do
      assert_raises(IdentityCredentialRemovalCommitter::TransactionConflict) do
        IdentityCredentialRemovalCommitter.call!(
          actor: actor, credential: credential, current_session: token,
          step_up_evidence: nil,
        )
      end
    end

    assert_equal ClientTotpCredentialStatus::ACTIVE, credential.reload.user_identity_totp_credential_status_id
  end

  test "current Step-Up evidence can release a bound Telephone contact" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_clients << actor
    actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "remaining-key", uv_verified_at: Time.current,
    )
    telephone = ClientTelephone.create!(
      user: actor, number: "+819012345684", confirm_policy: "1",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )
    telephone.finalize_binding!
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
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
    step_up_evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)

    assert IdentityCredentialRemovalCommitter.call!(
      actor: actor, credential: telephone, current_session: token, actor_context: context,
      step_up_evidence: step_up_evidence,
    )
    assert_predicate telephone.reload, :binding_released?
    assert_predicate token.reload, :currently_usable?
    OpBaseAppRecord.transaction do
      assert StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: token.reload)
    end
  end

  test "current Step-Up evidence can release a bound Email contact" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_clients << actor
    actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "remaining-key", uv_verified_at: Time.current,
    )
    email = ClientEmail.create!(
      user: actor, address: "release-unbound-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
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
    step_up_evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)

    assert IdentityCredentialRemovalCommitter.call!(
      actor: actor, credential: email, current_session: token, actor_context: context,
      step_up_evidence: step_up_evidence,
    )
    assert_predicate email.reload, :binding_released?
    assert_predicate token.reload, :currently_usable?
    OpBaseAppRecord.transaction do
      assert StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: token.reload)
    end
  end

  test "the same current Step-Up evidence authorizes multiple eligible TOTP removals" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_clients << actor
    actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "remaining-key", uv_verified_at: Time.current,
    )
    first = actor.client_totp_credentials.create!(
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    target = actor.client_totp_credentials.create!(
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
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
    step_up_evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )

    assert IdentityCredentialRemovalCommitter.call!(
      actor: actor, credential: target, current_session: token, step_up_evidence: step_up_evidence,
    )
    assert_equal ClientTotpCredentialStatus::DELETED, target.reload.user_totp_credential_status_id
    assert IdentityCredentialRemovalCommitter.call!(
      actor: actor, credential: first, current_session: token, step_up_evidence: step_up_evidence,
    )
    assert_equal ClientTotpCredentialStatus::DELETED, first.reload.user_totp_credential_status_id
    OpBaseAppRecord.transaction do
      assert StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: token.reload)
    end
  end

  test "a login-blocked owner cannot remove a TOTP" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_clients << actor
    actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "remaining-key", uv_verified_at: Time.current,
    )
    credential = actor.client_totp_credentials.create!(
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    session_state = token.attributes.slice(
      "root_login_established_at", "established_authentication_method",
      "discard_at",
    )
    actor.reload.update!(status_id: ClientStatus::RESERVED)

    assert_not IdentityCredentialRemovalCommitter.call!(
      actor: actor, credential: credential, current_session: token,
      step_up_evidence: nil,
    )
    assert_equal ClientTotpCredentialStatus::ACTIVE, credential.reload.user_identity_totp_credential_status_id
    assert_equal session_state, token.reload.attributes.slice(*session_state.keys)
  end

  test "a revoked device cannot authorize TOTP credential removal" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_clients << actor
    actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "remaining-key", uv_verified_at: Time.current,
    )
    credential = actor.client_totp_credentials.create!(
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    token.device_session_record!.revoke!

    assert_not IdentityCredentialRemovalCommitter.call!(
      actor: actor, credential: credential, current_session: token,
      step_up_evidence: nil,
    )
    assert_equal ClientTotpCredentialStatus::ACTIVE, credential.reload.user_identity_totp_credential_status_id
  end

  test "pending Contacts are refused without releasing ownership or changing the session" do
    [
      [Client, ClientEmail, ClientToken, ClientContactAuditOutbox, :user_id, :app,
       { address: "pending-removal@example.test" },],
      [Client, ClientTelephone, ClientToken, ClientContactAuditOutbox, :user_id, :app, { number: "+819012345687" }],
    ].each do |owner_class, contact_class, token_class, outbox_class, owner_key, surface, attributes|
      owner = owner_class.create!(security_mode_id: SecurityModeTestDefault.id_for(owner_class))
      @created_clients << owner
      contact = contact_class.create!(attributes.merge(owner_key => owner.id, :confirm_policy => "1"))
      token = token_class.create!(:authentication_epoch => 0, owner_key => owner.id)
      previous = token.attributes.slice("root_login_established_at", "established_authentication_method", "discard_at")
      contact_before = contact.attributes
      context = ActorValuesContext.empty.with(
        subject: owner, actor_type: :client, tld: surface, surface: :base,
      )

      assert_no_difference -> { outbox_class.where(contact_ref: contact.public_id).count } do
        assert_not IdentityCredentialRemovalCommitter.call!(
          actor: owner, credential: contact, current_session: token, actor_context: context,
          step_up_evidence: nil,
        )
      end
      assert_equal contact_before, contact.reload.attributes
      assert_equal previous, token.reload.attributes.slice(*previous.keys)
      assert_nil contact.binding_finalized_at
      assert_nil contact.binding_released_at
    end
  end

  test "Contact release and Source intent roll back together without resurrecting invalidated authority" do
    [
      [Client, ClientEmail, ClientToken, ClientContactAuditOutbox, :user_id, :app],
    ].each do |owner_class, contact_class, token_class, outbox_class, owner_key, surface|
      owner = owner_class.create!(security_mode_id: SecurityModeTestDefault.id_for(owner_class))
      @created_clients << owner
      attributes = { owner_key => owner.id, :address => "rollback-release@example.test", :confirm_policy => "1" }
      if surface == :app
        attributes[:user_email_status_id] = ClientEmailStatus::VERIFIED
      end
      contact = contact_class.create!(attributes)
      contact.finalize_binding!
      if surface == :app
        owner.client_passkeys.create!(
          webauthn_id: SecureRandom.uuid, public_key: "fallback",
          uv_verified_at: Time.current,
        )
      end
      token = token_class.create!(:authentication_epoch => 0, owner_key => owner.id)
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
      step_up_evidence = StepUpEvidenceValue.new(
        acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
        sub: OidcSubject.for(owner, resource_type: "client"), client_id: oidc_client.client_id,
        aud: [oidc_client.aud], jti: grant.oidc_jti,
      )
      context = ActorValuesContext.empty.with(
        subject: owner, actor_type: :client, tld: surface, surface: :base,
      )
      contact_class.transaction(requires_new: true) do
        assert IdentityCredentialRemovalCommitter.call!(
          actor: owner, credential: contact, current_session: token, actor_context: context,
          step_up_evidence: step_up_evidence,
        )
        assert_predicate contact.reload, :binding_released?
        assert outbox_class.exists?(contact_ref: contact.public_id)
        raise ActiveRecord::Rollback
      end

      assert_predicate contact.reload, :binding_effective?
      assert_not outbox_class.exists?(contact_ref: contact.public_id)
      assert_predicate token, :currently_usable?
      OpBaseAppRecord.transaction do
        assert StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: owner, token: token.reload)
      end
    end
  end

  test "Contact removal refuses missing anonymous foreign role and realm contexts before clearing authority" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    @created_clients << owner
    foreign = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    @created_clients << foreign
    contact = ClientEmail.create!(user_id: owner.id, address: "release-context@example.test", confirm_policy: "1")
    contact.finalize_binding!
    token = ClientToken.create!(authentication_epoch: 0, user: owner)
    session_state = token.attributes.slice(
      "root_login_established_at", "established_authentication_method",
      "discard_at",
    )
    valid = ActorValuesContext.empty.with(subject: owner, actor_type: :client, tld: :app, surface: :base)
    [nil, ActorValuesContext.empty.with(tld: :app), valid.with(subject: foreign),
     valid.with(actor_type: :operator), valid.with(tld: :org),].each do |context|
      error =
        assert_raises(ArgumentError) do
          IdentityCredentialRemovalCommitter.call!(
            actor: owner, credential: contact, current_session: token, actor_context: context,
            step_up_evidence: nil,
          )
        end
      assert_equal "Contact removal requires its authenticated Actor context", error.message
      assert_predicate contact.reload, :binding_effective?
      assert_not ClientContactAuditOutbox.exists?(contact_ref: contact.public_id)
      assert_equal session_state, token.reload.attributes.slice(*session_state.keys)
    end
  end

  test "Contact release records one Source intent and an exact terminal retry adds none" do
    [
      [Client, ClientEmail, ClientToken, ClientContactAuditOutbox, :user_id, "email", :app],
      [Client, ClientTelephone, ClientToken, ClientContactAuditOutbox, :user_id, "telephone", :app],
    ].each do |owner_class, contact_class, token_class, outbox_class, owner_key, kind, surface|
      owner = owner_class.create!(security_mode_id: SecurityModeTestDefault.id_for(owner_class))
      @created_clients << owner
      attributes = (kind == "email") ? { address: "release@example.test" } : { number: "+819012345686" }
      contact = contact_class.create!(attributes.merge(owner_key => owner.id, :confirm_policy => "1"))
      case contact
      when ClientEmail then contact.update!(user_email_status_id: ClientEmailStatus::VERIFIED)
      when ClientTelephone then contact.update!(user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED)
      else raise ArgumentError, "unsupported test contact"
      end
      contact.finalize_binding!
      if surface == :app
        owner.client_passkeys.create!(
          webauthn_id: SecureRandom.uuid, public_key: "fallback",
          uv_verified_at: Time.current,
        )
      end
      token = token_class.create!(:authentication_epoch => 0, owner_key => owner.id)
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
      step_up_evidence = StepUpEvidenceValue.new(
        acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
        sub: OidcSubject.for(owner, resource_type: "client"), client_id: oidc_client.client_id,
        aud: [oidc_client.aud], jti: grant.oidc_jti,
      )
      context = ActorValuesContext.empty.with(
        subject: owner, actor_type: :client, tld: surface, surface: :base,
      )
      assert_difference -> { outbox_class.where(contact_ref: contact.public_id).count }, 1 do
        assert IdentityCredentialRemovalCommitter.call!(
          actor: owner, credential: contact, current_session: token, actor_context: context,
          step_up_evidence: step_up_evidence,
        )
      end
      event = outbox_class.find_by!(contact_ref: contact.public_id)

      assert_predicate contact.reload, :binding_released?
      assert_equal [kind, "released", owner.public_id, owner.public_id],
                   [event.contact_kind, event.event_name, event.owner_ref, event.actor_ref]
      assert_nil event.acknowledged_at
      assert_predicate token.reload, :currently_usable?
      assert_no_difference -> { outbox_class.where(contact_ref: contact.public_id).count } do
        assert_not IdentityCredentialRemovalCommitter.call!(
          actor: owner, credential: contact, current_session: token, actor_context: context,
          step_up_evidence: step_up_evidence,
        )
      end
      assert_equal event.event_uuid, outbox_class.find_by!(contact_ref: contact.public_id).event_uuid
    end
  end

  test "a temporarily locked Email refuses last Passkey removal without changing the session" do
    %i(app).each do |surface|
      actor, token, passkey, email =
        if surface == :app
          actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_111_000_000_000)
          @created_clients << actor
          email = actor.client_emails.create!(
            address: "locked-app-#{SecureRandom.hex(8)}@example.com",
            user_email_status_id: ClientEmailStatus::VERIFIED,
            step_up_otp_locked_until: Client.database_now + 1.hour,
          )
          passkey = actor.client_passkeys.create!(
            webauthn_id: SecureRandom.uuid, public_key: "last-key",
            uv_verified_at: Time.current,
          )
          [actor, ClientToken.create!(authentication_epoch: 0, user: actor), passkey, email]
        end
      session_state = token.attributes.slice(
        "root_login_established_at", "established_authentication_method",
        "discard_at",
      )
      status = passkey.status_id
      locked_until = email.step_up_otp_locked_until

      assert_not IdentityCredentialRemovalCommitter.call!(
        actor: actor, credential: passkey, current_session: token,
        step_up_evidence: nil,
      )
      assert_equal status, passkey.reload.status_id
      assert_equal session_state, token.reload.attributes.slice(*session_state.keys)
      assert_equal locked_until, email.reload.step_up_otp_locked_until
      assert_predicate token, :currently_usable?
    end
  end

  test "an expired Passkey or Email fallback cannot authorize removal of the usable Passkey" do
    %i(app).each do |surface|
      %i(passkey email).each_with_index do |fallback_kind, index|
        actor, token, target, fallback =
          if surface == :app
            actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_109_000_000_000 + index)
            @created_clients << actor
            target = actor.client_passkeys.create!(
              webauthn_id: SecureRandom.uuid, public_key: "usable-key",
              uv_verified_at: Time.current,
            )
            fallback =
              if fallback_kind == :passkey
                actor.client_passkeys.create!(
                  webauthn_id: SecureRandom.uuid, public_key: "expired-key",
                  uv_verified_at: Time.current,
                )
              else
                actor.client_emails.create!(
                  address: "expired-app-#{SecureRandom.hex(8)}@example.com",
                  user_email_status_id: ClientEmailStatus::VERIFIED,
                )
              end
            [actor, ClientToken.create!(authentication_epoch: 0, user: actor), target, fallback]
          end
        fallback.update!(discard_at: actor.class.database_now)
        session_state = token.attributes.slice(
          "root_login_established_at", "established_authentication_method",
          "discard_at",
        )

        assert_not IdentityCredentialRemovalCommitter.call!(
          actor: actor, credential: target, current_session: token,
          step_up_evidence: nil,
        )
        assert_equal session_state, token.reload.attributes.slice(*session_state.keys)
        expected_status = ClientPasskeyStatus::ACTIVE

        assert_equal expected_status, target.reload.status_id
        assert_predicate token, :currently_usable?
      end
    end
  end

  test "removal deletes passkeys or retains terminal non-passkey credentials while preserving root sessions" do
    %i(app org totp).each do |surface|
      actor, token, credential, terminal_status =
        case surface
        when :app, :totp
          actor = Client.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL,
            id: 9_108_000_000_000 + SecureRandom.random_number(1_000_000_000),
          )
          @created_clients << actor

          assert_equal 0, actor.client_passkeys.count
          actor.client_passkeys.create!(
            webauthn_id: SecureRandom.uuid, public_key: "fallback-key",
            uv_verified_at: Time.current,
          )
          credential =
            if surface == :totp
              actor.client_totp_credentials.create!(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
            else
              actor.client_passkeys.create!(
                webauthn_id: SecureRandom.uuid, public_key: "removed-key",
                uv_verified_at: Time.current,
              )
            end
          [actor, ClientToken.create!(authentication_epoch: 0, user: actor), credential,
           (surface == :totp) ? ClientTotpCredentialStatus::DELETED : ClientPasskeyStatus::DELETED,]
        when :org
          actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
          @created_operators << actor
          # D-132: two Passkeys stay after the removal.
          OperatorPasskeyTestSupport.give_two_active_passkeys!(actor)
          actor.staff_passkeys.create!(
            webauthn_id: SecureRandom.uuid, public_key: "fallback-key",
            uv_verified_at: Time.current,
          )
          credential = actor.staff_passkeys.create!(
            webauthn_id: SecureRandom.uuid, public_key: "removed-key",
            uv_verified_at: Time.current,
          )
          [actor, OperatorToken.create!(authentication_epoch: 0, staff: actor), credential, OperatorPasskeyStatus::REVOKED]
        end
      if actor.is_a?(Client)
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
        step_up_evidence = StepUpEvidenceValue.new(
          acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
          sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
          aud: [oidc_client.aud], jti: grant.oidc_jti,
        )
      else
        now = OpBaseOrgRecord.database_now
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
        step_up_evidence = StepUpEvidenceValue.new(
          acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
          sub: OidcSubject.for(actor, resource_type: "operator"), client_id: oidc_client.client_id,
          aud: [oidc_client.aud], jti: grant.oidc_jti,
        )
      end
      transaction_model, ceremony_model =
        case actor
        when Client then [ClientStepUpCeremonyTransaction, ClientAuthCeremonySession]
        when Operator then [OperatorStepUpCeremonyTransaction, OperatorAuthCeremonySession]
        end
      unfinished = transaction_model.create_transaction!(
        actor_ref: actor.public_id, session_ref: token.public_id, required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], return_to: "/identity/birthdate",
      )
      continuity, = ceremony_model.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: unfinished.transaction_id,
      )
      removed_id = credential.id

      removed = IdentityCredentialRemovalCommitter.call!(
        actor: actor, credential: credential, current_session: token,
        step_up_evidence: step_up_evidence,
      )

      assert removed, "surface=#{surface}"

      if credential.is_a?(ClientPasskey) || credential.is_a?(OperatorPasskey)
        assert_raises(ActiveRecord::RecordNotFound) { credential.reload }
        outbox_class =
          case credential
          when ClientPasskey then ClientPasskeyAuditOutbox
          when OperatorPasskey then OperatorPasskeyAuditOutbox
          end

        assert outbox_class.exists?(external_id: credential.external_id, event_type: "passkey.removed")
      else
        credential.reload

        assert_equal terminal_status, credential.user_identity_totp_credential_status_id
        assert_equal removed_id, credential.id
      end

      if actor.is_a?(Client)
        OpBaseAppRecord.transaction do
          assert StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: token.reload)
        end
      else
        OpBaseOrgRecord.transaction do
          assert StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: token.reload)
        end
      end

      assert_equal "revoked", unfinished.reload.status
      assert_not_nil continuity.reload.revoked_at
      assert_predicate token, :currently_usable?
      assert_not StepUpBootstrapEligibilityQuery.call(actor: actor)
      if credential.destroyed?
        assert_raises(ArgumentError) do
          IdentityCredentialRemovalCommitter.call!(
            actor: actor, credential: credential, current_session: token,
            step_up_evidence: step_up_evidence,
          )
        end
      else
        assert_not IdentityCredentialRemovalCommitter.call!(
          actor: actor, credential: credential,
          current_session: token,
          step_up_evidence: step_up_evidence,
        )
      end
    end
  end

  test "the last ORG Passkey and a foreign actor credential are refused" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    @created_operators << actor
    foreign_actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    @created_operators << foreign_actor
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
    credential = actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "last-key",
      uv_verified_at: Time.current,
    )
    foreign = foreign_actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "foreign-key",
      uv_verified_at: Time.current,
    )

    assert_not IdentityCredentialRemovalCommitter.call!(
      actor: actor, credential: credential, current_session: token,
      step_up_evidence: nil,
    )
    assert_raises(ArgumentError) do
      IdentityCredentialRemovalCommitter.call!(
        actor: actor, credential: foreign, current_session: token,
        step_up_evidence: nil,
      )
    end
    assert_equal OperatorPasskeyStatus::ACTIVE, credential.reload.status_id
    assert_equal OperatorPasskeyStatus::ACTIVE, foreign.reload.status_id
  end

  test "ticket failure leaves an owned credential active and preserves reusable evidence" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    @created_operators << actor
    # D-132: two Passkeys stay after the removal.
    OperatorPasskeyTestSupport.give_two_active_passkeys!(actor)
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
    actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "fallback-key",
      uv_verified_at: Time.current,
    )
    credential = actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "removed-key",
      uv_verified_at: Time.current,
    )
    now = OpBaseOrgRecord.database_now
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
    step_up_evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "operator"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    session_state = token.attributes.slice(
      "root_login_established_at", "established_authentication_method",
      "discard_at",
    )

    CredentialSecurityTransition.stub(
      :call, ->(**) {
               raise ActiveRecord::ConnectionNotEstablished, "injected ticket outage"
             },
    ) do
      assert_raises(IdentityCredentialRemovalCommitter::DependencyFailure) do
        IdentityCredentialRemovalCommitter.call!(
          actor: actor, credential: credential, current_session: token,
          step_up_evidence: step_up_evidence,
        )
      end
    end
    assert_equal OperatorPasskeyStatus::ACTIVE, credential.reload.status_id
    assert_equal session_state, token.reload.attributes.slice(*session_state.keys)
    OpBaseOrgRecord.transaction do
      assert StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: token.reload)
    end
    token.revoke!

    assert_raises(ArgumentError) do
      IdentityCredentialRemovalCommitter.call!(
        actor: actor, credential: credential, current_session: token,
        step_up_evidence: nil,
      )
    end
    assert_equal OperatorPasskeyStatus::ACTIVE, credential.reload.status_id
  end
  test "missing bindings, another session owner and Emergency context cannot remove a credential" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    @created_operators << actor
    other = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    @created_operators << other
    credential = actor.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "owned-key")
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
    foreign_token = OperatorToken.create!(authentication_epoch: 0, staff: other)
    emergency = OperatorToken.create!(authentication_epoch: 0, staff: actor, authentication_context: AuthenticationContextValue::STANDBY_KEY)

    [[nil, credential, token], [actor, nil, token], [actor, credential, nil],
     [actor, credential, foreign_token], [actor, credential, emergency],].each do |owner, target, session|
      assert_raises(ArgumentError) do
        IdentityCredentialRemovalCommitter.call!(
          actor: owner, credential: target, current_session: session,
          step_up_evidence: nil,
        )
      end
      assert_equal OperatorPasskeyStatus::ACTIVE, credential.reload.status_id
    end
  end
end
