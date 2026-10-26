# frozen_string_literal: true

require "test_helper"

class IdentityEmailPreferenceCommitterTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a changed preference spends Step-Up once and a no-op keeps a new Step-Up" do
    actor, token, email = authorized_email

    IdentityEmailPreferenceCommitter.call!(
      actor:, token:, email:, preferences: { "promotional" => "0", "notifiable" => "1" },
    )

    assert_not email.reload.promotional?
    assert_predicate email, :notifiable?
    assert_nil token.reload.last_step_up_at
    assert_raises(IdentityEmailPreferenceCommitter::Denied) do
      IdentityEmailPreferenceCommitter.call!(
        actor:, token: token.reload, email:, preferences: { "promotional" => "1" },
      )
    end
    assert_not email.reload.promotional?

    grant_email_step_up!(actor, token.reload)
    no_op_evidence = token.reload.attributes
    IdentityEmailPreferenceCommitter.call!(
      actor:, token:, email:, preferences: { "promotional" => "0", "notifiable" => "1" },
    )

    assert_equal no_op_evidence, token.reload.attributes
  end

  test "locked preferences, unsupported keys and foreign email retain evidence" do
    actor, token, email = authorized_email
    email.update!(user_email_status_id: ClientEmailStatus::UNVERIFIED)
    grant_email_step_up!(actor, token)
    original = [email.reload.promotional, email.notifiable]
    evidence = token.reload.attributes

    IdentityEmailPreferenceCommitter.call!(
      actor:, token:, email:, preferences: { "promotional" => "0", "notifiable" => "0" },
    )

    assert_equal original, [email.reload.promotional, email.notifiable]
    assert_equal evidence, token.reload.attributes
    assert_raises(ArgumentError) do
      IdentityEmailPreferenceCommitter.call!(actor:, token:, email:, preferences: { "unexpected" => "x" })
    end

    foreign_actor, _foreign_token, = authorized_email
    assert_raises(IdentityEmailPreferenceCommitter::Denied) do
      IdentityEmailPreferenceCommitter.call!(
        actor: foreign_actor, token:, email:, preferences: { "promotional" => "0" },
      )
    end
    assert_equal evidence, token.reload.attributes
  end

  private

  def authorized_email
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    email = ClientEmail.create!(
      user: actor, address: "preferences-#{SecureRandom.hex(6)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    grant_email_step_up!(actor, token)
    [actor, token, email]
  end

  def grant_email_step_up!(_actor, token)
    now = ClientToken.database_now
    token.update!(
      last_step_up_at: now, last_step_up_scope: "settings_email", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false, last_step_up_credential_ref: "test-step-up",
      last_step_up_full_reauthentication: false,
    )
  end
end
