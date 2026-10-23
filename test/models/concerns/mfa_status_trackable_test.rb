# typed: false
# frozen_string_literal: true

require "test_helper"

class MfaStatusTrackableTest < ActiveSupport::TestCase
  test "credential callback refreshes persisted MFA without saving or discarding unrelated cached owner edits" do
    owner = create_client!
    persisted_status = owner.status_id
    owner.status_id = ClientStatus::ACTIVE
    ClientEmail.create!(
      user: owner, address: "cached-owner-mfa@example.test", binding_finalized_at: ClientEmail.database_now,
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_equal ClientStatus::ACTIVE, owner.status_id
    assert_predicate owner, :changed?
    persisted = Client.find(owner.id)

    assert_equal persisted_status, persisted.status_id
    assert_equal ClientMfaStatus::ACTIVE, persisted.mfa_status_id
  end

  test "new actors default status to unconfigured" do
    assert_equal ClientMfaStatus::UNCONFIGURED, Client.new(security_mode_id: SecurityModeConfigurable::NORMAL).mfa_status_id
    assert_equal OperatorMfaStatus::UNCONFIGURED, Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED).mfa_status_id
    assert_equal VisitorMfaStatus::UNCONFIGURED, Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL).mfa_status_id
  end

  test "user refreshes to unconfigured without app step up methods" do
    # Keep this owner outside committed test/dev credential rows keyed by fixture-range IDs.
    user = create_client!

    assert_equal ClientMfaStatus::UNCONFIGURED, user.reload.mfa_status_id
    assert_predicate user, :mfa_status_unconfigured?
  end

  test "raises when placeholder status is used for runtime checks" do
    user = create_client!
    user.update_column(:mfa_status_id, ClientMfaStatus::NOTHING)

    assert_raises(MfaStatusTrackable::InvalidMfaStatus) do
      user.reload.mfa_status_unconfigured?
    end
  end

  test "assigns unconfigured before validation when placeholder is present" do
    user = create_client!
    user.update_column(:mfa_status_id, ClientMfaStatus::NOTHING)

    user = Client.find(user.id)

    assert_predicate user, :valid?

    assert_equal ClientMfaStatus::UNCONFIGURED, user.mfa_status_id
  end

  test "user refreshes to active with verified email" do
    user = create_client!

    ClientEmail.create!(
      user: user,
      address: "mfs-user-#{SecureRandom.hex(4)}@example.com",
      binding_finalized_at: ClientEmail.database_now,
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_equal ClientMfaStatus::ACTIVE, user.reload.mfa_status_id
    assert_predicate user, :mfa_status_active?
  end

  test "user refreshes from unconfigured to active after verified email registration" do
    user = create_client!

    assert_equal ClientMfaStatus::UNCONFIGURED, user.reload.mfa_status_id

    ClientEmail.create!(
      user: user,
      address: "mfs-unconfigured-user-#{SecureRandom.hex(4)}@example.com",
      binding_finalized_at: ClientEmail.database_now,
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_equal ClientMfaStatus::ACTIVE, user.reload.mfa_status_id
  end

  test "user refresh ignores stale loaded email association" do
    user = create_client!
    user = Client.includes(:client_emails).find(user.id)

    ClientEmail.create!(
      user: user,
      address: "mfs-stale-user-#{SecureRandom.hex(4)}@example.com",
      binding_finalized_at: ClientEmail.database_now,
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_equal ClientMfaStatus::ACTIVE, user.reload.mfa_status_id
  end

  test "user refreshes back to unconfigured when last method is no longer verified" do
    user = create_client!
    email = ClientEmail.create!(
      user: user,
      address: "mfs-demote-user-#{SecureRandom.hex(4)}@example.com",
      binding_finalized_at: ClientEmail.database_now,
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    email.update!(user_email_status_id: ClientEmailStatus::UNVERIFIED)

    assert_equal ClientMfaStatus::UNCONFIGURED, user.reload.mfa_status_id
  end

  test "operator refreshes to active with passkey" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)

    OperatorPasskey.create!(
      staff: operator,
      description: "Security key",
      public_key: "public-key",
      webauthn_id: SecureRandom.hex(16),
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    assert_equal OperatorMfaStatus::ACTIVE, operator.reload.mfa_status_id
  end

  test "visitor refreshes to active with verified email" do
    visitor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL)

    VisitorEmail.create!(
      visitor: visitor,
      address: "mfs-visitor-#{SecureRandom.hex(4)}@example.com",
      binding_finalized_at: VisitorEmail.database_now,
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )

    assert_equal VisitorMfaStatus::ACTIVE, visitor.reload.mfa_status_id
  end

  private

  def create_client!
    # Keep this owner outside committed test/dev credential rows keyed by fixture-range IDs.
    Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: 1_000_000_000_000 + SecureRandom.random_number(1_000_000_000),
    )
  end
end
