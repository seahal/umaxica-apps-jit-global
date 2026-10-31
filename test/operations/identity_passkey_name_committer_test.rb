# frozen_string_literal: true

require "test_helper"

# AC-P08: a changed description writes exactly one edit event; an identical value and authenticator
# maintenance write none, and the free text is not copied into the audit row.
class IdentityPasskeyNameCommitterTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []
  fixtures :client_token_binding_methods, :operator_token_binding_methods,
           :client_token_dbsc_statuses, :operator_token_dbsc_statuses

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
        refs = ClientPasskey.where(user_id: actor.id).select(:external_id)
        ClientPasskeyAuditOutbox.where(external_id: refs).delete_all
        ClientPasskey.where(user_id: actor.id).delete_all
        ClientDeviceSession.where(user_id: actor.id).update_all(current_refresh_token_id: nil)
        ClientToken.where(user_id: actor.id).delete_all
        ClientDeviceSession.where(user_id: actor.id).delete_all
        ClientPreference.where(client_id: actor.id).destroy_all
        Client.where(id: actor.id).delete_all
      else
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
    evidence = actor.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "evidence-key")
    target = actor.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "target-key", description: "Original",
    )
    normal = OperatorToken.create!(authentication_epoch: 0, staff: actor, authentication_context: "normal")
    standby = OperatorToken.create!(authentication_epoch: 0, staff: actor, authentication_context: "standby")
    [normal, standby].each do |token|
      token.update!(
        last_step_up_at: OperatorToken.database_now, last_step_up_scope: "settings_passkey",
        last_step_up_method: "passkey", last_step_up_credential_ref: evidence.external_id,
        last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
        last_step_up_audience: "step_up:org", last_step_up_phishing_resistant: true,
        last_step_up_user_verified: true, last_step_up_full_reauthentication: false,
        last_step_up_resource_ref: target.external_id,
      )
    end

    IdentityPasskeyNameCommitter.call!(actor: actor, token: normal, passkey: target, description: "Normal")

    assert_equal "Normal", target.reload.description
    assert_nil normal.reload.last_step_up_at
    assert_equal 1, OperatorPasskeyAuditOutbox.where(external_id: target.external_id).count
    assert_raises(IdentityPasskeyNameCommitter::Denied) do
      IdentityPasskeyNameCommitter.call!(actor: actor, token: standby, passkey: target, description: "Standby")
    end
    assert_equal "Normal", target.reload.description
    assert_equal 1, OperatorPasskeyAuditOutbox.where(external_id: target.external_id).count
    assert_predicate standby.reload.last_step_up_at, :present?
  end

  test "Step-Up bound to another Passkey cannot rename the target on either surface" do
    SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
      actor, token, passkey = authorized_passkey(actor_class, key_class, token_class, owner_key, surface)
      token.update!(last_step_up_resource_ref: token.last_step_up_credential_ref)

      assert_raises(IdentityPasskeyNameCommitter::Denied, surface) do
        IdentityPasskeyNameCommitter.call!(actor:, token:, passkey:, description: "Denied")
      end
      assert_equal "Original", passkey.reload.description
      assert_equal 0, outbox_class.where(external_id: passkey.external_id).count
      assert_predicate token.reload.last_step_up_at, :present?
    end
  end

  test "unbound Step-Up cannot rename a Passkey on either surface" do
    SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
      actor, token, passkey = authorized_passkey(actor_class, key_class, token_class, owner_key, surface)
      token.update!(last_step_up_resource_ref: nil)

      assert_raises(IdentityPasskeyNameCommitter::Denied, surface) do
        IdentityPasskeyNameCommitter.call!(actor:, token:, passkey:, description: "Denied")
      end
      assert_equal "Original", passkey.reload.description
      assert_equal 0, outbox_class.where(external_id: passkey.external_id).count
      assert_predicate token.reload.last_step_up_at, :present?
    end
  end

  test "a changed description writes one edit event without copying the text on every surface" do
    SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
      actor, token, passkey = authorized_passkey(actor_class, key_class, token_class, owner_key, surface)

      IdentityPasskeyNameCommitter.call!(actor:, token:, passkey:, description: "Private laptop name")

      events = outbox_class.where(external_id: passkey.external_id)

      assert_equal ["passkey.description_changed"], events.pluck(:event_type), surface
      assert_equal "Private laptop name", passkey.reload.description
      assert_not_includes events.first.metadata.to_json, "Private laptop name", surface
      assert_not_includes events.first.metadata.to_json, "Original", surface
    end
  end

  # adr/authentication-security-mode.md D3: one Step-Up authorizes one rename.
  test "a second rename with the same Step-Up is refused on every surface" do
    SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
      actor, token, passkey = authorized_passkey(actor_class, key_class, token_class, owner_key, surface)

      IdentityPasskeyNameCommitter.call!(actor:, token:, passkey:, description: "First name")

      assert_raises(IdentityPasskeyNameCommitter::Denied, surface) do
        IdentityPasskeyNameCommitter.call!(actor:, token: token.reload, passkey:, description: "Second name")
      end
      assert_equal "First name", passkey.reload.description, surface
      assert_equal 1, outbox_class.where(external_id: passkey.external_id).count, surface
    end
  end

  test "an identical description writes no edit event on every surface" do
    SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
      actor, token, passkey = authorized_passkey(actor_class, key_class, token_class, owner_key, surface)

      IdentityPasskeyNameCommitter.call!(actor:, token:, passkey:, description: "Original")

      assert_equal 0, outbox_class.where(external_id: passkey.external_id).count, surface
    end
  end

  test "authenticator maintenance writes no edit event on every surface" do
    SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
      _actor, _token, passkey = authorized_passkey(actor_class, key_class, token_class, owner_key, surface)
      maintenance = { sign_count: passkey.sign_count + 1, last_used_at: Time.current }
      maintenance[:uv_verified_at] = Time.current unless key_class == OperatorPasskey

      passkey.update!(maintenance)

      assert_equal 0, outbox_class.where(external_id: passkey.external_id).count, surface
    end
  end

  [false, true].each do |savepoint|
    test "an outer OP transaction with savepoint #{savepoint} refuses rename on every surface" do
      SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
        actor, token, passkey = authorized_passkey(actor_class, key_class, token_class, owner_key, surface)
        evidence_at = token.reload.last_step_up_at
        op_record = (surface == "app") ? OpBaseAppRecord : OpBaseOrgRecord

        op_record.transaction do
          op_record.transaction(requires_new: savepoint) do
            assert_raises(IdentityPasskeyNameCommitter::DependencyFailure, surface) do
              IdentityPasskeyNameCommitter.call!(actor:, token:, passkey:, description: "Changed")
            end
          end
          raise ActiveRecord::Rollback
        end

        assert_equal "Original", passkey.reload.description, surface
        assert_equal evidence_at, token.reload.last_step_up_at, surface
        assert_equal 0, outbox_class.where(external_id: passkey.external_id).count, surface
      end
    end
  end

  # XDB-02 failure window A: the Step-Up consumption committed on op_base, then the zenith
  # rename transaction fails. The proof must stay spent, the name must stay unchanged with no
  # audit row, and the operation must report the denial instead of a rename.
  test "a zenith-side failure after the consumption commit reports denial and keeps the name" do
    SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
      actor, token, passkey = authorized_passkey(actor_class, key_class, token_class, owner_key, surface)
      injected = ->(**_kwargs) { raise ActiveRecord::ConnectionNotEstablished, "injected audit failure" }

      PasskeyAuditOutbox.stub(:record_for!, injected) do
        assert_raises(IdentityPasskeyNameCommitter::DependencyFailure, surface) do
          IdentityPasskeyNameCommitter.call!(actor:, token:, passkey:, description: "Failed rename")
        end
      end

      assert_equal "Original", passkey.reload.description, surface
      assert_equal 0, outbox_class.where(external_id: passkey.external_id).count, surface
      # The proof is spent: the consumption commit completed ahead of the failed zenith phase.
      cleared = token.reload

      assert_nil cleared.last_step_up_method, "#{surface} proof must be spent"
      assert_nil cleared.last_step_up_credential_ref, "#{surface} proof must be spent"
    end
  end

  # XDB-02 failure window B: the Step-Up consumption itself lost the race for the proof row and
  # could not commit. Nothing is spent, nothing is renamed, no audit row is written.
  test "an uncommittable Step-Up consumption reports denial and changes nothing" do
    SURFACES.each do |actor_class, key_class, token_class, outbox_class, owner_key, surface|
      actor, token, passkey = authorized_passkey(actor_class, key_class, token_class, owner_key, surface)
      evidence_before = token.attributes.slice(
        "last_step_up_method", "last_step_up_credential_ref", "last_step_up_session_public_id",
      )
      failure =
        lambda { |*_args|
          raise TokenStatusManagement::StepUpEvidenceUnavailable, "injected consumption failure"
        }

      token.stub(:consume_step_up_evidence!, failure) do
        assert_raises(IdentityPasskeyNameCommitter::Denied, surface) do
          IdentityPasskeyNameCommitter.call!(actor:, token:, passkey:, description: "Lost race")
        end
      end

      assert_equal "Original", passkey.reload.description, surface
      assert_equal 0, outbox_class.where(external_id: passkey.external_id).count, surface
      assert_equal evidence_before, token.reload.attributes.slice(*evidence_before.keys),
                   "#{surface} proof must survive a consumption failure"
    end
  end

  private

  def authorized_passkey(actor_class, key_class, token_class, owner_key, surface)
    actor = actor_class.create!(security_mode_id: SecurityModeTestDefault.id_for(actor_class))
    @actors << actor
    token = token_class.create!(:authentication_epoch => 0, owner_key => actor.id)
    metadata = (key_class == OperatorPasskey) ? {} : { uv_verified_at: Time.current }
    evidence_key = key_class.create!(
      owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "evidence-key", **metadata,
    )
    passkey = key_class.create!(
      owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "target-key",
      :description => "Original", **metadata,
    )
    token.update!(
      last_step_up_at: token_class.database_now,
      last_step_up_scope: "settings_passkey",
      last_step_up_method: "passkey",
      last_step_up_credential_ref: (key_class == OperatorPasskey) ? evidence_key.external_id : evidence_key.public_id,
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:#{surface}",
      last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
      last_step_up_resource_ref: (key_class == OperatorPasskey) ? passkey.external_id : passkey.public_id,
    )
    [actor, token, passkey]
  end
end
