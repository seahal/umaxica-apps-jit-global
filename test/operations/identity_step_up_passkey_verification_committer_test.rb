# frozen_string_literal: true

require "test_helper"
require "support/webauthn_fake_client_helper"

class IdentityStepUpPasskeyVerificationCommitterTest < ActiveSupport::TestCase
  include WebauthnFakeClientHelper

  fixtures :clients, :client_statuses

  setup do
    @actor = clients(:one)
    @fake = webauthn_fake_client
    @credential = @actor.client_passkeys.create!(fake_credential_record_attrs(@fake))
    @token = ClientToken.create!(user: @actor)
    @transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: @actor.public_id, session_ref: @token.public_id,
      required_scope: "settings_birthdate", required_aal: "none", allowed_methods: ["passkey"],
      return_to: "/identity/birthdate",
    )
    @record = ClientStepUpSession.create!(
      user_token: @token, step_up_ceremony_transaction_ref: @transaction.transaction_id,
      scope: @transaction.required_scope, return_to: @transaction.return_to,
      status: "PENDING", discard_at: @transaction.expires_at,
    )
    @config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.app", origin: @fake.origin)
    options = Webauthn::AssertionVerifier.options_for(
      config: @config, allow_ids: [@credential.webauthn_id], purpose: :ordinary_step_up,
    )
    @reference = @record.issue_bound_passkey_challenge!(
      transaction: @transaction, challenge: options.challenge,
      rp_id: @config.rp_id, origin: @config.origin,
    )
    @assertion = fake_assertion(@fake, challenge: options.challenge, sign_count: 5)
  end

  test "real assertion records the exact credential once without establishing Base freshness" do
    IdentityStepUpPasskeyVerificationCommitter.call!(
      actor: @actor, transaction: @transaction, session_record: @record, config: @config,
      reference: @reference, credential_params: @assertion,
    )

    assert_equal "verified", @transaction.reload.status
    assert_equal @credential.public_id, @transaction.verified_credential_ref
    assert_equal "passkey", @transaction.method
    assert_equal 5, @credential.reload.sign_count
    assert_not_nil @credential.uv_verified_at
    assert_nil @token.reload.last_step_up_at
    assert_raises(StepUpSessionConsumable::ChallengeError) do
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: @actor, transaction: @transaction, session_record: @record, config: @config,
        reference: @reference, credential_params: @assertion,
      )
    end
  end

  test "missing UV burns the challenge and leaves the transaction unverified" do
    assertion = fake_assertion(@fake, challenge: @record.passkey_challenge, user_verified: false)
    assert_raises(WebAuthn::UserVerifiedVerificationError) do
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: @actor, transaction: @transaction, session_record: @record, config: @config,
        reference: @reference, credential_params: assertion,
      )
    end
    assert_not_nil @record.reload.passkey_challenge_consumed_at
    assert_equal "pending", @transaction.reload.status
    assert_equal 0, @credential.reload.sign_count
  end

  test "a removed credential is rejected despite an otherwise valid signature" do
    @credential.update!(discard_at: Time.current)
    assert_raises(ActiveRecord::RecordNotFound) do
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: @actor, transaction: @transaction, session_record: @record, config: @config,
        reference: @reference, credential_params: @assertion,
      )
    end
    assert_not_nil @record.reload.passkey_challenge_consumed_at
    assert_equal "pending", @transaction.reload.status
    assert_nil @token.reload.last_step_up_at
  end

  test "a credential belonging to another actor is rejected" do
    @credential.update!(user: clients(:two))
    assert_raises(ActiveRecord::RecordNotFound) do
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: @actor, transaction: @transaction, session_record: @record, config: @config,
        reference: @reference, credential_params: @assertion,
      )
    end
    assert_equal "pending", @transaction.reload.status
    assert_nil @token.reload.last_step_up_at
  end

  test "a token belonging to another actor cannot advance the admitted transaction" do
    @record.update!(user_token: ClientToken.create!(user: clients(:two)))
    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: @actor, transaction: @transaction, session_record: @record.reload, config: @config,
        reference: @reference, credential_params: @assertion,
      )
    end
    assert_nil @record.reload.passkey_challenge_consumed_at
    assert_equal "pending", @transaction.reload.status
  end
end
