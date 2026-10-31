# frozen_string_literal: true

require "test_helper"

class IdentityCredentialRemovalCommitterTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "unbound Step-Up cannot release a Telephone contact" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "remaining-key", uv_verified_at: Time.current,
    )
    telephone = ClientTelephone.create!(
      user: actor, number: "+819012345684", confirm_policy: "1",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )
    telephone.finalize_binding!
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_telephone",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true, last_step_up_credential_ref: "evidence",
      last_step_up_full_reauthentication: false,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)

    assert_not IdentityCredentialRemovalCommitter.call!(
      actor: actor, credential: telephone, current_session: token, actor_context: context,
    )
    assert_predicate telephone.reload, :binding_effective?
    assert_predicate token.reload.last_step_up_at, :present?
  end

  test "unbound Step-Up cannot release an Email contact" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "remaining-key", uv_verified_at: Time.current,
    )
    email = ClientEmail.create!(
      user: actor, address: "release-unbound-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_email", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true, last_step_up_credential_ref: "evidence",
      last_step_up_full_reauthentication: false,
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)

    assert_not IdentityCredentialRemovalCommitter.call!(
      actor: actor, credential: email, current_session: token, actor_context: context,
    )
    assert_predicate email.reload, :binding_effective?
    assert_predicate token.reload.last_step_up_at, :present?
  end

  test "a Step-Up bound to another TOTP cannot authorize removal" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
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
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_totp", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true, last_step_up_credential_ref: "evidence",
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: first.public_id,
    )

    assert_not IdentityCredentialRemovalCommitter.call!(actor: actor, credential: target, current_session: token)
    assert_equal ClientTotpCredentialStatus::ACTIVE, target.reload.user_identity_totp_credential_status_id
    assert_predicate token.reload.last_step_up_at, :present?
    token.update!(last_step_up_resource_ref: nil)

    assert_not IdentityCredentialRemovalCommitter.call!(actor: actor, credential: target, current_session: token)
    assert_equal ClientTotpCredentialStatus::ACTIVE, target.reload.user_identity_totp_credential_status_id
    assert_predicate token.reload.last_step_up_at, :present?
  end

  test "a login-blocked owner cannot remove a TOTP with earlier Step-Up" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    passkey = actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "remaining-key", uv_verified_at: Time.current,
    )
    credential = actor.client_totp_credentials.create!(
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_totp", last_step_up_method: "passkey",
      last_step_up_credential_ref: passkey.public_id, last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: credential.public_id,
    )
    actor.reload.update!(status_id: ClientStatus::RESERVED)
    step_up_at = token.last_step_up_at

    assert_not IdentityCredentialRemovalCommitter.call!(actor: actor, credential: credential, current_session: token)
    assert_equal ClientTotpCredentialStatus::ACTIVE, credential.reload.user_identity_totp_credential_status_id
    assert_equal step_up_at, token.reload.last_step_up_at
  end

  test "a revoked device cannot authorize TOTP credential removal" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "remaining-key", uv_verified_at: Time.current,
    )
    credential = actor.client_totp_credentials.create!(
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    token.device_session_record!.revoke!

    assert_not IdentityCredentialRemovalCommitter.call!(actor: actor, credential: credential, current_session: token)
    assert_equal ClientTotpCredentialStatus::ACTIVE, credential.reload.user_identity_totp_credential_status_id
  end

  test "pending Contacts are refused without releasing ownership or invalidating Root freshness" do
    [
      [Client, ClientEmail, ClientToken, ClientContactAuditOutbox, :user_id, :app,
       { address: "pending-removal@example.test" },],
      [Client, ClientTelephone, ClientToken, ClientContactAuditOutbox, :user_id, :app, { number: "+819012345687" }],
    ].each do |owner_class, contact_class, token_class, outbox_class, owner_key, surface, attributes|
      owner = owner_class.create!(security_mode_id: SecurityModeTestDefault.id_for(owner_class))
      contact = contact_class.create!(attributes.merge(owner_key => owner.id, :confirm_policy => "1"))
      token = token_class.create!(:authentication_epoch => 0, owner_key => owner.id)
      token.update!(last_step_up_at: token_class.database_now, last_step_up_scope: "settings_email")
      previous = token.attributes.slice("last_step_up_at", "last_step_up_scope", "discard_at")
      contact_before = contact.attributes
      context = ActorValuesContext.empty.with(
        subject: owner, actor_type: :client, tld: surface, surface: :base,
      )

      assert_no_difference -> { outbox_class.where(contact_ref: contact.public_id).count } do
        assert_not IdentityCredentialRemovalCommitter.call!(
          actor: owner, credential: contact, current_session: token, actor_context: context,
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
      token.update!(
        last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_email", last_step_up_method: "passkey",
        last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
        last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: true,
        last_step_up_user_verified: true,
        last_step_up_credential_ref: ClientPasskey.find_by!(user_id: owner.id).public_id,
        last_step_up_full_reauthentication: false, last_step_up_resource_ref: contact.public_id,
      )
      context = ActorValuesContext.empty.with(
        subject: owner, actor_type: :client, tld: surface, surface: :base,
      )
      contact_class.transaction(requires_new: true) do
        assert IdentityCredentialRemovalCommitter.call!(
          actor: owner, credential: contact, current_session: token, actor_context: context,
        )
        assert_predicate contact.reload, :binding_released?
        assert outbox_class.exists?(contact_ref: contact.public_id)
        raise ActiveRecord::Rollback
      end

      assert_predicate contact.reload, :binding_effective?
      assert_not outbox_class.exists?(contact_ref: contact.public_id)
      assert_nil token.reload.last_step_up_at
      assert_predicate token, :currently_usable?
    end
  end

  test "Contact removal refuses missing anonymous foreign role and realm contexts before clearing authority" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    foreign = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    contact = ClientEmail.create!(user_id: owner.id, address: "release-context@example.test", confirm_policy: "1")
    contact.finalize_binding!
    token = ClientToken.create!(authentication_epoch: 0, user: owner)
    token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_email")
    freshness = token.last_step_up_at
    valid = ActorValuesContext.empty.with(subject: owner, actor_type: :client, tld: :app, surface: :base)
    [nil, ActorValuesContext.empty.with(tld: :app), valid.with(subject: foreign),
     valid.with(actor_type: :operator), valid.with(tld: :org),].each do |context|
      error =
        assert_raises(ArgumentError) do
          IdentityCredentialRemovalCommitter.call!(
            actor: owner, credential: contact, current_session: token, actor_context: context,
          )
        end
      assert_equal "Contact removal requires its authenticated Actor context", error.message
      assert_predicate contact.reload, :binding_effective?
      assert_not ClientContactAuditOutbox.exists?(contact_ref: contact.public_id)
      assert_equal freshness, token.reload.last_step_up_at
    end
  end

  test "Contact release records one Source intent and an exact terminal retry adds none" do
    [
      [Client, ClientEmail, ClientToken, ClientContactAuditOutbox, :user_id, "email", :app],
      [Client, ClientTelephone, ClientToken, ClientContactAuditOutbox, :user_id, "telephone", :app],
    ].each do |owner_class, contact_class, token_class, outbox_class, owner_key, kind, surface|
      owner = owner_class.create!(security_mode_id: SecurityModeTestDefault.id_for(owner_class))
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
      token.update!(
        last_step_up_at: ClientToken.database_now,
        last_step_up_scope: (kind == "email") ? "settings_email" : "settings_telephone",
        last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
        last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
        last_step_up_credential_ref: ClientPasskey.find_by!(user_id: owner.id).public_id,
        last_step_up_full_reauthentication: false, last_step_up_resource_ref: contact.public_id,
      )
      context = ActorValuesContext.empty.with(
        subject: owner, actor_type: :client, tld: surface, surface: :base,
      )
      assert_difference -> { outbox_class.where(contact_ref: contact.public_id).count }, 1 do
        assert IdentityCredentialRemovalCommitter.call!(
          actor: owner, credential: contact, current_session: token, actor_context: context,
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
        )
      end
      assert_equal event.event_uuid, outbox_class.find_by!(contact_ref: contact.public_id).event_uuid
    end
  end

  test "a temporarily locked Email refuses last Passkey removal without clearing authority" do
    %i(app).each do |surface|
      actor, token, passkey, email =
        if surface == :app
          actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_111_000_000_000)
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
      token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_passkey")
      event = token.last_step_up_at
      status = passkey.status_id
      locked_until = email.step_up_otp_locked_until

      assert_not IdentityCredentialRemovalCommitter.call!(actor: actor, credential: passkey, current_session: token)
      assert_equal status, passkey.reload.status_id
      assert_equal event, token.reload.last_step_up_at
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
        token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_passkey")
        event = token.last_step_up_at

        assert_not IdentityCredentialRemovalCommitter.call!(actor: actor, credential: target, current_session: token)
        assert_equal event, token.reload.last_step_up_at
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
      evidence_ref =
        case credential
        when ClientPasskey then credential.public_id
        when OperatorPasskey then credential.external_id
        when ClientTotpCredential then actor.client_passkeys.active.first!.public_id
        else raise ArgumentError, "unsupported credential"
        end
      evidence_surface = (surface == :totp) ? :app : surface
      token.update!(
        last_step_up_at: Time.current, last_step_up_scope: (surface == :totp) ? "settings_totp" : "settings_passkey",
        last_step_up_method: "passkey",
        last_step_up_credential_ref: evidence_ref, last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:#{evidence_surface}",
        last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
        last_step_up_full_reauthentication: false,
        last_step_up_resource_ref: (surface == :totp) ? credential.public_id : evidence_ref,
      )
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

      assert_nil token.reload.last_step_up_at
      assert_equal "revoked", unfinished.reload.status
      assert_not_nil continuity.reload.revoked_at
      assert_predicate token, :currently_usable?
      assert_not StepUpBootstrapEligibilityQuery.call(actor: actor)
      if credential.destroyed?
        assert_raises(ArgumentError) do
          IdentityCredentialRemovalCommitter.call!(actor: actor, credential: credential, current_session: token)
        end
      else
        assert_not IdentityCredentialRemovalCommitter.call!(
          actor: actor, credential: credential,
          current_session: token,
        )
      end
    end
  end

  test "the last ORG Passkey and a foreign actor credential are refused without changing authority" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    foreign_actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
    token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_passkey")
    credential = actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "last-key",
      uv_verified_at: Time.current,
    )
    foreign = foreign_actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "foreign-key",
      uv_verified_at: Time.current,
    )
    timestamp = token.last_step_up_at

    assert_not IdentityCredentialRemovalCommitter.call!(actor: actor, credential: credential, current_session: token)
    assert_raises(ArgumentError) do
      IdentityCredentialRemovalCommitter.call!(actor: actor, credential: foreign, current_session: token)
    end
    assert_equal OperatorPasskeyStatus::ACTIVE, credential.reload.status_id
    assert_equal OperatorPasskeyStatus::ACTIVE, foreign.reload.status_id
    assert_equal timestamp, token.reload.last_step_up_at
  end
  test "revoked session and ticket failure leave an owned credential active" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
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
    token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_passkey", last_step_up_method: "passkey",
      last_step_up_credential_ref: credential.external_id, last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:org",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: credential.external_id,
    )
    timestamp = token.last_step_up_at

    CredentialSecurityTransition.stub(
      :call, ->(**) {
               raise ActiveRecord::ConnectionNotEstablished, "injected ticket outage"
             },
    ) do
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        IdentityCredentialRemovalCommitter.call!(actor: actor, credential: credential, current_session: token)
      end
    end
    assert_equal OperatorPasskeyStatus::ACTIVE, credential.reload.status_id
    assert_equal timestamp, token.reload.last_step_up_at
    token.revoke!

    assert_raises(ArgumentError) do
      IdentityCredentialRemovalCommitter.call!(actor: actor, credential: credential, current_session: token)
    end
    assert_equal OperatorPasskeyStatus::ACTIVE, credential.reload.status_id
  end
  test "missing bindings, another session owner and Emergency context cannot remove a credential" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    other = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    credential = actor.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "owned-key")
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
    foreign_token = OperatorToken.create!(authentication_epoch: 0, staff: other)
    emergency = OperatorToken.create!(authentication_epoch: 0, staff: actor, authentication_context: AuthenticationContextValue::STANDBY_KEY)

    [[nil, credential, token], [actor, nil, token], [actor, credential, nil],
     [actor, credential, foreign_token], [actor, credential, emergency],].each do |owner, target, session|
      assert_raises(ArgumentError) do
        IdentityCredentialRemovalCommitter.call!(actor: owner, credential: target, current_session: session)
      end
      assert_equal OperatorPasskeyStatus::ACTIVE, credential.reload.status_id
    end
  end
end
