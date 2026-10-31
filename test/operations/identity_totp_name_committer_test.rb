# frozen_string_literal: true

require "test_helper"

class IdentityTotpNameCommitterTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @created_client_ids = []
  end

  teardown do
    ClientTotpCredential.where(user_id: @created_client_ids).delete_all
    ClientDeviceSession.where(user_id: @created_client_ids).update_all(current_refresh_token_id: nil)
    ClientToken.where(user_id: @created_client_ids).delete_all
    ClientDeviceSession.where(user_id: @created_client_ids).delete_all
    Client.where(id: @created_client_ids).delete_all
  end
  self.fixture_table_names = []

  test "unbound and other-credential Step-Up cannot rename a TOTP credential" do
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
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_totp", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false, last_step_up_credential_ref: "test-step-up",
      last_step_up_full_reauthentication: false,
    )

    assert_raises(IdentityTotpNameCommitter::Denied) do
      IdentityTotpNameCommitter.call!(actor:, token:, credential: first, title: "First")
    end
    token.update!(last_step_up_resource_ref: first.public_id)

    assert_raises(IdentityTotpNameCommitter::Denied) do
      IdentityTotpNameCommitter.call!(actor:, token:, credential: second, title: "Second")
    end
    assert_nil first.reload.title
    assert_nil second.reload.title
    assert_predicate token.reload.last_step_up_at, :present?
    IdentityTotpNameCommitter.call!(actor:, token:, credential: first, title: "First")

    assert_equal "First", first.reload.title
    assert_nil token.reload.last_step_up_at
  end

  test "a superseded device token cannot authorize a TOTP rename" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_totp", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false, last_step_up_credential_ref: "test-step-up",
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: credential.public_id,
    )
    device = token.device_session_record!
    replacement = ClientToken.create!(authentication_epoch: 0, user: actor, device_session: device)
    device.update!(current_refresh_token_id: replacement.id)

    assert_raises(IdentityTotpNameCommitter::Denied) do
      IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "Denied")
    end
    assert_nil credential.reload.title
    assert_predicate token.reload.last_step_up_at, :present?
  end

  test "a revoked device cannot authorize a TOTP rename" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_totp", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false, last_step_up_credential_ref: "test-step-up",
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: credential.public_id,
    )
    token.device_session_record!.revoke!

    assert_raises(IdentityTotpNameCommitter::Denied) do
      IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "Denied")
    end
    assert_nil credential.reload.title
    assert_predicate token.reload.last_step_up_at, :present?
  end

  test "a failed OP consumption observes the original TOTP title" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_totp", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false, last_step_up_credential_ref: "test-step-up",
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: credential.public_id,
    )
    observed_title = "not-observed"
    failure =
      lambda do |**|
        observed_title = ClientTotpCredential.find(credential.id).title
        raise TokenStatusManagement::StepUpEvidenceUnavailable, "injected OP consumption failure"
      end

    token.stub(:consume_step_up_evidence!, failure) do
      assert_raises(IdentityTotpNameCommitter::Denied) do
        IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "New title")
      end
    end

    assert_nil observed_title
    assert_nil credential.reload.title
    assert_predicate token.reload.last_step_up_at, :present?
  end

  test "a failed Zenith rename preserves the title and spends Step-Up" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_totp", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false, last_step_up_credential_ref: "test-step-up",
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: credential.public_id,
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
        IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "New title")
      end
    end

    assert failed
    assert_nil credential.reload.title
    assert_nil token.reload.last_step_up_at
  end

  test "a successful rename spends Step-Up once and a no-op keeps a new Step-Up" do
    actor, token, credential, = authorized_totp

    IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "Phone authenticator")

    assert_equal "Phone authenticator", credential.reload.title
    assert_nil token.reload.last_step_up_at
    assert_raises(IdentityTotpNameCommitter::Denied) do
      IdentityTotpNameCommitter.call!(actor:, token: token.reload, credential:, title: "Another name")
    end
    assert_equal "Phone authenticator", credential.reload.title

    grant_totp_step_up!(actor, token.reload, credential)
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
    @created_client_ids << actor.id
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    requirement = grant_totp_step_up!(actor, token, credential)
    [actor, token, credential, requirement]
  end

  def grant_totp_step_up!(actor, token, credential)
    now = ClientToken.database_now
    token.update!(
      last_step_up_at: now, last_step_up_scope: "settings_totp", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false, last_step_up_credential_ref: "test-step-up",
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: credential.public_id,
    )
    StepUpRequirement.new(
      scope: "settings_totp", step_up_required: true, allowed_methods: %i(passkey totp email_otp),
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, purpose: "step_up", audience: "step_up:app",
      session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
      ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: actor.public_id, resource_ref: credential.public_id,
      tenant_ref: nil,
    )

  end
end
