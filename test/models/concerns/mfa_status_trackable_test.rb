# typed: false
# frozen_string_literal: true

require "test_helper"

class MfaStatusTrackableTest < ActiveSupport::TestCase
  test "new actors default status to unconfigured" do
    assert_equal ClientMfaStatus::UNCONFIGURED, Client.new.mfa_status_id
    assert_equal OperatorMfaStatus::UNCONFIGURED, Operator.new.mfa_status_id
    assert_equal VisitorMfaStatus::UNCONFIGURED, Visitor.new.mfa_status_id
  end

  test "user refreshes to unconfigured without app step up methods" do
    user = Client.create!

    assert_equal ClientMfaStatus::UNCONFIGURED, user.reload.mfa_status_id
    assert_predicate user, :mfa_status_unconfigured?
  end

  test "raises when placeholder status is used for runtime checks" do
    user = Client.create!
    user.update_column(:mfa_status_id, ClientMfaStatus::NOTHING)

    assert_raises(MfaStatusTrackable::InvalidMfaStatus) do
      user.reload.mfa_status_unconfigured?
    end
  end

  test "assigns unconfigured before validation when placeholder is present" do
    user = Client.create!
    user.update_column(:mfa_status_id, ClientMfaStatus::NOTHING)

    user = Client.find(user.id)

    assert_predicate user, :valid?

    assert_equal ClientMfaStatus::UNCONFIGURED, user.mfa_status_id
  end

  test "user refreshes to active with verified email" do
    user = Client.create!

    ClientEmail.create!(
      user: user,
      address: "mfs-user-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_equal ClientMfaStatus::ACTIVE, user.reload.mfa_status_id
    assert_predicate user, :mfa_status_active?
  end

  test "user refreshes from unconfigured to active after verified email registration" do
    user = Client.create!

    assert_equal ClientMfaStatus::UNCONFIGURED, user.reload.mfa_status_id

    ClientEmail.create!(
      user: user,
      address: "mfs-unconfigured-user-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_equal ClientMfaStatus::ACTIVE, user.reload.mfa_status_id
  end

  test "user refresh ignores stale loaded email association" do
    user = Client.create!
    user.client_emails.load

    ClientEmail.create!(
      user: user,
      address: "mfs-stale-user-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_equal ClientMfaStatus::ACTIVE, user.reload.mfa_status_id
  end

  test "user refreshes back to unconfigured when last method is no longer verified" do
    user = Client.create!
    email = ClientEmail.create!(
      user: user,
      address: "mfs-demote-user-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    email.update!(user_email_status_id: ClientEmailStatus::UNVERIFIED)

    assert_equal ClientMfaStatus::UNCONFIGURED, user.reload.mfa_status_id
  end

  test "operator refreshes to active with passkey" do
    operator = Operator.create!

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
    visitor = Visitor.create!

    VisitorEmail.create!(
      visitor: visitor,
      address: "mfs-visitor-#{SecureRandom.hex(4)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )

    assert_equal VisitorMfaStatus::ACTIVE, visitor.reload.mfa_status_id
  end
end
