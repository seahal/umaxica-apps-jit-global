# frozen_string_literal: true

require "test_helper"

class IdentityTotpNameCommitterTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a successful rename spends Step-Up once and a no-op keeps a new Step-Up" do
    actor, token, credential, = authorized_totp

    IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "Phone authenticator")

    assert_equal "Phone authenticator", credential.reload.title
    assert_nil token.reload.last_step_up_at
    assert_raises(IdentityTotpNameCommitter::Denied) do
      IdentityTotpNameCommitter.call!(actor:, token: token.reload, credential:, title: "Another name")
    end
    assert_equal "Phone authenticator", credential.reload.title

    grant_totp_step_up!(actor, token.reload)
    no_op_evidence = token.reload.attributes

    assert_equal credential.id,
                 IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "Phone authenticator").id
    assert_equal no_op_evidence, token.reload.attributes
  end

  test "invalid names and foreign credentials retain evidence" do
    actor, token, credential, = authorized_totp
    original = token.reload.attributes

    assert_raises(IdentityTotpNameCommitter::InvalidTitle) do
      IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "x" * 33)
    end
    assert_equal original, token.reload.attributes
    assert_nil credential.reload.title

    foreign_actor, = authorized_totp
    assert_raises(IdentityTotpNameCommitter::Denied) do
      IdentityTotpNameCommitter.call!(actor: foreign_actor, token:, credential:, title: "Foreign")
    end
    assert_equal original, token.reload.attributes
  end

  private

  def authorized_totp
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    requirement = grant_totp_step_up!(actor, token)
    [actor, token, credential, requirement]
  end

  def grant_totp_step_up!(actor, token)
    now = ClientToken.database_now
    token.update!(
      last_step_up_at: now, last_step_up_scope: "settings_totp", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false, last_step_up_credential_ref: "test-step-up",
      last_step_up_full_reauthentication: false,
    )
    StepUpRequirement.new(
      scope: "settings_totp", step_up_required: true, allowed_methods: %i(passkey totp email_otp),
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, purpose: "step_up", audience: "step_up:app",
      session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
      ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )

  end
end
