# typed: false
# frozen_string_literal: true

require "test_helper"

# Consolidation ADR 2.3: Step-Up validity is at most 15 minutes in NORMAL and 5 minutes in ADVANCED,
# and ADVANCED accepts only Passkey evidence. Boundaries are checked one second inside and exactly at
# each limit.
class StepUpResolverSecurityModeTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  NOW = Time.zone.parse("2026-10-24 00:00:00")

  test "NORMAL evidence is current one second before 15 minutes and expired at 15 minutes" do
    token = token_for(SecurityModeConfigurable::NORMAL, method: "totp")

    assert satisfied?(token, age: 15.minutes - 1.second)
    assert_not satisfied?(token, age: 15.minutes)
  end

  test "ADVANCED evidence is current one second before 5 minutes and expired at 5 minutes" do
    token = token_for(SecurityModeConfigurable::ADVANCED, method: "passkey")

    assert satisfied?(token, age: 5.minutes - 1.second)
    assert_not satisfied?(token, age: 5.minutes)
  end

  test "a requirement TTL shorter than the mode maximum still applies" do
    token = token_for(SecurityModeConfigurable::NORMAL, method: "passkey")

    assert satisfied?(token, age: 59.seconds, ttl: 1.minute)
    assert_not satisfied?(token, age: 1.minute, ttl: 1.minute)
  end

  test "ADVANCED refuses non-Passkey evidence that NORMAL accepts" do
    advanced = token_for(SecurityModeConfigurable::ADVANCED, method: "totp")
    normal = token_for(SecurityModeConfigurable::NORMAL, method: "totp")

    assert_not satisfied?(advanced, age: 1.second)
    assert satisfied?(normal, age: 1.second)
  end

  test "configured Step-Up methods keep only the Passkey in ADVANCED and none for an invalid mode" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    ClientPasskey.create!(
      user_id: actor.id, webauthn_id: SecureRandom.uuid, public_key: "resolver-key", uv_verified_at: Time.current,
    )
    normal_methods = StepUpConfiguredMethodsQuery.call(actor)

    assert_includes normal_methods, :passkey
    actor.update_column(:security_mode_id, SecurityModeConfigurable::ADVANCED)

    assert_equal [:passkey], StepUpConfiguredMethodsQuery.call(actor.reload)
    # The foreign key keeps an invalid mode out of the database; an unsaved one still offers nothing.
    actor.security_mode_id = 0

    assert_empty StepUpConfiguredMethodsQuery.call(actor)
  end

  private

  def token_for(mode, method:)
    actor = Client.create!(security_mode_id: mode, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor, root_login_established_at: NOW)
    token.update!(
      last_step_up_scope: "settings_email", last_step_up_method: method,
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:resolver", last_step_up_credential_ref: SecureRandom.uuid,
      last_step_up_phishing_resistant: false, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    token
  end

  def satisfied?(token, age:, ttl: StepUpRequirement::DEFAULT_TTL)
    token.update_column(:last_step_up_at, NOW - age)
    StepUpResolver.call(
      token: token, scope: "settings_email", allowed_methods: %i(passkey totp), now: NOW, ttl: ttl,
    ).satisfied
  end
end
