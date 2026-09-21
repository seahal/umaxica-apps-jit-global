# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitors
# Database name: com_zenith
#
#  id                          :bigint           not null, primary key
#  access_state                :string           default("enabled"), not null
#  admin_locked_at             :datetime
#  admin_locked_reason_code    :string
#  admin_locked_reason_note    :text
#  birthdate                   :text
#  deactivated_at              :datetime
#  discard_at                :datetime         default(Infinity), not null
#  lock_version                :integer          default(0), not null
#  mfa_level_enabled           :boolean          default(FALSE), not null
#  purge_eligible_at                   :datetime         default(Infinity), not null
#  reactivated_at              :datetime
#  terminated_at               :datetime
#  token_valid_after_at        :datetime
#  webauthn_user_handle        :string           not null
#  withdrawal_started_at       :datetime
#  withdrawn_at                :datetime         default(Infinity)
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  admin_locked_by_operator_id :bigint
#  mfa_level_id                :bigint           default(0), not null
#  mfa_status_id               :bigint           default(5), not null
#  public_id                   :string           default(""), not null
#  status_id                   :bigint           default(2), not null
#  visibility_id               :bigint           default(1), not null
#
# Indexes
#
#  index_visitors_on_access_state           (access_state)
#  index_visitors_on_admin_locked_at        (admin_locked_at) WHERE (admin_locked_at IS NOT NULL)
#  index_visitors_on_deactivated_at         (deactivated_at) WHERE (deactivated_at IS NOT NULL)
#  index_visitors_on_discard_at           (discard_at)
#  index_visitors_on_mfa_level_id           (mfa_level_id)
#  index_visitors_on_mfa_status_id          (mfa_status_id)
#  index_visitors_on_public_id              (public_id) UNIQUE
#  index_visitors_on_purge_eligible_at              (purge_eligible_at)
#  index_visitors_on_status_id              (status_id)
#  index_visitors_on_terminated_at          (terminated_at) WHERE (terminated_at IS NOT NULL)
#  index_visitors_on_token_valid_after_at   (token_valid_after_at) WHERE (token_valid_after_at IS NOT NULL)
#  index_visitors_on_visibility_id          (visibility_id)
#  index_visitors_on_webauthn_user_handle   (webauthn_user_handle) UNIQUE
#  index_visitors_on_withdrawal_started_at  (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL)
#  index_visitors_on_withdrawn_at           (withdrawn_at) WHERE (withdrawn_at IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (mfa_level_id => visitor_mfa_levels.id)
#  fk_rails_...  (mfa_status_id => visitor_mfa_statuses.id)
#  fk_rails_...  (status_id => visitor_statuses.id)
#  fk_rails_...  (visibility_id => visitor_visibilities.id)
#

require "test_helper"

class VisitorTest < ActiveSupport::TestCase
  test "mfa_level_enabled and mfa_level_id must describe the same requirement" do
    visitor = Visitor.new(mfa_level_enabled: true, mfa_level_id: VisitorMfaLevel::NOTHING)

    assert_not visitor.valid?
    assert_not_empty visitor.errors[:mfa_level_id]

    visitor = Visitor.new(mfa_level_enabled: false, mfa_level_id: VisitorMfaLevel::FULL)

    assert_not visitor.valid?
    assert_not_empty visitor.errors[:mfa_level_enabled]
  end

  test "termination requires finite withdrawal completion" do
    visitor = Visitor.new(terminated_at: Time.current)

    assert_not visitor.valid?
    assert_not_empty visitor.errors[:terminated_at]

    visitor.withdrawn_at = 1.minute.ago

    assert_predicate visitor, :valid?
  end

  test "withdrawal completion cannot precede withdrawal start" do
    visitor = Visitor.new(withdrawal_started_at: Time.current, withdrawn_at: 1.minute.ago)

    assert_not visitor.valid?
    assert_not_empty visitor.errors[:withdrawn_at]
  end

  def setup
    Prosopite.pause do
      VisitorMfaLevel.ensure_defaults!
      VisitorMfaStatus.ensure_defaults!
      VisitorStatus.ensure_defaults!
      VisitorVisibility.ensure_defaults!
      VisitorTelephoneStatus.ensure_defaults!
      VisitorEmailStatus.ensure_defaults!
      VisitorPasskeyStatus.ensure_defaults!
    end
  end

  test "should be valid" do
    visitor = Visitor.create!

    assert_predicate visitor, :valid?
  end

  test "public_id is auto-generated" do
    visitor = Visitor.create!

    assert_predicate visitor.public_id, :present?
    assert_operator visitor.public_id.length, :<=, 21
  end

  test "default status_id is nothing" do
    visitor = Visitor.create!

    assert_equal VisitorStatus::NOTHING, visitor.status_id
  end

  test "default visibility_id is visitor" do
    visitor = Visitor.create!

    assert_equal VisitorVisibility::VISITOR, visitor.visibility_id
  end

  test "visitor? should return true" do
    visitor = Visitor.create!

    assert_predicate visitor, :visitor?
  end

  test "user? should return false" do
    visitor = Visitor.create!

    assert_not visitor.user?
  end

  test "staff? should return false" do
    visitor = Visitor.create!

    assert_not visitor.staff?
  end

  test "login_allowed? is false for reserved status" do
    visitor = Visitor.create!(status_id: VisitorStatus::RESERVED)

    assert_not visitor.login_allowed?
  end

  test "verified_email? returns true when visitor has verified email" do
    visitor = Visitor.create!
    VisitorEmail.create!(
      visitor: visitor,
      address: "verified@example.com",
      confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )

    assert_predicate visitor, :verified_email?
  end

  test "verified_email? uses loaded visitor_emails" do
    visitor = Visitor.create!
    VisitorEmail.create!(
      visitor: visitor,
      address: "loaded@example.com",
      confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    visitor.visitor_emails.load

    assert_predicate visitor, :verified_email?
  end

  test "verified_email? returns true when visitor has verified_with_sign_up email" do
    visitor = Visitor.create!
    VisitorEmail.create!(
      visitor: visitor,
      address: "signup@example.com",
      confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED_WITH_SIGN_UP,
    )

    assert_predicate visitor, :verified_email?
  end

  test "verified_email? returns false when visitor has no verified email" do
    visitor = Visitor.create!
    VisitorEmail.create!(
      visitor: visitor,
      address: "unverified@example.com",
      confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::UNVERIFIED,
    )

    assert_not visitor.verified_email?
  end

  test "verified_telephone? returns true when visitor has verified telephone" do
    visitor = Visitor.create!
    VisitorTelephone.create!(
      visitor: visitor,
      number: "+15551234567",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    assert_predicate visitor, :verified_telephone?
  end

  test "verified_telephone? uses loaded visitor_telephones" do
    visitor = Visitor.create!
    VisitorTelephone.create!(
      visitor: visitor,
      number: "+15557654321",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    visitor.visitor_telephones.load

    assert_predicate visitor, :verified_telephone?
  end

  test "verified_telephone? returns false when visitor has no verified telephone" do
    visitor = Visitor.create!
    VisitorTelephone.create!(
      visitor: visitor,
      number: "+15551234567",
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED,
    )

    assert_not visitor.verified_telephone?
  end

  test "has_verified_pii? returns true when has verified email" do
    visitor = Visitor.create!
    VisitorEmail.create!(
      visitor: visitor,
      address: "verified@example.com",
      confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )

    assert_predicate visitor, :has_verified_pii?
  end

  test "has_verified_pii? returns true when has verified telephone" do
    visitor = Visitor.create!
    VisitorTelephone.create!(
      visitor: visitor,
      number: "+15551234567",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    assert_predicate visitor, :has_verified_pii?
  end

  test "has_verified_pii? returns false when no verified identity" do
    visitor = Visitor.create!

    assert_not visitor.has_verified_pii?
  end

  test "has_verified_recovery_identity? delegates to has_verified_pii?" do
    visitor = Visitor.create!

    assert_equal visitor.has_verified_pii?, visitor.has_verified_recovery_identity?
  end

  test "passkey_login_available? returns false when no passkeys" do
    visitor = Visitor.create!

    assert_not visitor.passkey_login_available?
  end

  test "passkey_login_available? requires verified telephone" do
    visitor = Visitor.create!
    VisitorTelephone.create!(
      visitor: visitor,
      number: "+15550001111",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    VisitorPasskey.create!(
      visitor: visitor,
      webauthn_id: "visitor-passkey-login",
      public_key: "test-public-key",
      description: "My Passkey",
    )

    assert_predicate visitor, :passkey_login_available?
  end

  test "passkey_login_available? uses loaded association when visitor_passkeys are loaded" do
    visitor = Visitor.create!
    VisitorTelephone.create!(
      visitor: visitor,
      number: "+15550002222",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    VisitorPasskey.create!(
      visitor: visitor,
      webauthn_id: "loaded-passkey",
      public_key: "loaded-public-key",
      description: "Loaded Passkey",
    )
    visitor.visitor_passkeys.load

    assert_predicate visitor, :passkey_login_available?
  end
end
