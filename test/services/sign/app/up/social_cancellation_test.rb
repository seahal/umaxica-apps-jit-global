# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"
# require "helpers/global_test_support"

class SignAppUpSocialCancellationTest < ActiveSupport::TestCase
  include ExternalIdentityTestHelper

  self.fixture_table_names = []

  setup do
    ClientStatus.ensure_defaults!
    ClientMfaStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
    ClientSignUpFlowStatus.ensure_defaults!
  end

  test "cancels google sign up and schedules pending identity and actor retention" do
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    identity = create_active_external_identity(client: user, provider: "google", subject: "cancel-google-sign-up")
    cycle = social_cycle(user, identity, provider: "google")

    result = SignAppUpSocialCancellation.call(cycle: cycle)

    assert_predicate result, :success?
    assert_equal ClientSignUpFlowStatus::CANCELLED, cycle.reload.status_id
    assert Client.exists?(user.id)
    assert_not user.reload.accessible?
    assert_not ClientExternalIdentity.exists?(identity.id)
  end

  test "cancels apple sign up and schedules pending identity and actor retention" do
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    identity = create_active_external_identity(client: user, provider: "apple", subject: "cancel-apple-sign-up")
    cycle = social_cycle(user, identity, provider: "apple")

    result = SignAppUpSocialCancellation.call(cycle: cycle)

    assert_predicate result, :success?
    assert_equal ClientSignUpFlowStatus::CANCELLED, cycle.reload.status_id
    assert Client.exists?(user.id)
    assert_not user.reload.accessible?
    assert_not ClientExternalIdentity.exists?(identity.id)
  end

  test "does not remove registered actor or identity" do
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    identity = create_active_external_identity(client: user, provider: "google", subject: "keep-registered-google")
    cycle = social_cycle(user, identity, provider: "google")

    result = SignAppUpSocialCancellation.call(cycle: cycle)

    assert_predicate result, :failure?
    assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, cycle.reload.status_id
    assert Client.exists?(user.id)
    assert ClientExternalIdentity.exists?(identity.id)
  end

  test "does not remove a social identity outside the current cycle actor" do
    pending_user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    other_user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    identity = create_active_external_identity(
      client: other_user, provider: "google",
      subject: "keep-other-cycle-google",
    )
    cycle = social_cycle(pending_user, identity, provider: "google")

    result = SignAppUpSocialCancellation.call(cycle: cycle)

    assert_predicate result, :failure?
    assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, cycle.reload.status_id
    assert Client.exists?(pending_user.id)
    assert Client.exists?(other_user.id)
    assert ClientExternalIdentity.exists?(identity.id)
  end

  private

  def social_cycle(user, identity, provider:)
    ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: user.id,
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      nonce_digest: ClientSignUpFlow.digest_nonce("nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
      entry_method: provider,
      social_provider: provider,
      pending_contact_type: "social_identity",
      pending_contact_id: identity.id,
    )
  end
end
