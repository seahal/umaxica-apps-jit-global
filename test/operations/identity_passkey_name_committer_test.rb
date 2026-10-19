# frozen_string_literal: true

require "test_helper"

# AC-P08: a changed description writes exactly one edit event; an identical value and authenticator
# maintenance write none, and the free text is not copied into the audit row.
class IdentityPasskeyNameCommitterTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  fixtures :client_token_binding_methods, :visitor_token_binding_methods, :operator_token_binding_methods,
           :client_token_dbsc_statuses, :visitor_token_dbsc_statuses, :operator_token_dbsc_statuses

  SURFACES = [
    [Client, ClientPasskey, ClientToken, ClientPasskeyAuditOutbox, :user_id, "app"],
    [Visitor, VisitorPasskey, VisitorToken, VisitorPasskeyAuditOutbox, :visitor_id, "com"],
    [Operator, OperatorPasskey, OperatorToken, OperatorPasskeyAuditOutbox, :staff_id, "org"],
  ].freeze

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

  private

  def authorized_passkey(actor_class, key_class, token_class, owner_key, surface)
    actor = actor_class.create!
    token = token_class.create!(owner_key => actor.id)
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
    )
    [actor, token, passkey]
  end
end
