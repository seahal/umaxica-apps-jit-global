# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: organization_invitations
# Database name: org_ticket
#
#  id              :bigint           not null, primary key
#  code            :string(32)       not null
#  consumed_at     :datetime
#  email           :string           not null
#  expires_at      :datetime         not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  invited_by_id   :bigint           not null
#  organization_id :bigint           not null
#  role_id         :bigint           default(0), not null
#
# Indexes
#
#  index_organization_invitations_on_code             (code) UNIQUE
#  index_organization_invitations_on_email            (email)
#  index_organization_invitations_on_invited_by_id    (invited_by_id)
#  index_organization_invitations_on_organization_id  (organization_id)
#

require "test_helper"

class OrganizationInvitationTest < ActiveSupport::TestCase
  def setup
    Prosopite.pause do
      [0, 1, 2, 3].each { |id| OrganizationStatus.find_or_create_by!(id: id) }
    end
    @staff = Operator.create!
    @organization = OperatorOrganization.create!(name: "Test Org", domain: "test-org-#{SecureRandom.hex(4)}")
    @invitation = OrganizationInvitation.create!(
      email: "invitee@example.com",
      organization_id: @organization.id,
      invited_by: @staff,
    )
  end

  test "should be valid" do
    assert_predicate @invitation, :valid?
  end

  test "should have code auto-generated on create" do
    assert_predicate @invitation.code, :present?
    assert_equal 32, @invitation.code.length
  end

  test "should have expires_at auto-set on create" do
    assert_predicate @invitation.expires_at, :present?
  end

  test "should have unique code" do
    assert_equal 1, OrganizationInvitation.where(code: @invitation.code).count
  end

  test "email presence validation" do
    invitation = OrganizationInvitation.new(
      email: nil,
      organization_id: @organization.id,
      invited_by: @staff,
    )

    assert_not invitation.valid?
    assert_not_empty invitation.errors[:email]
  end

  test "organization_id presence validation" do
    invitation = OrganizationInvitation.new(
      email: "test@example.com",
      organization_id: nil,
      invited_by: @staff,
    )

    assert_not invitation.valid?
    assert_not_empty invitation.errors[:organization_id]
  end

  test "invited_by_id presence validation" do
    invitation = OrganizationInvitation.new(
      email: "test@example.com",
      organization_id: @organization.id,
      invited_by: nil,
    )

    assert_not invitation.valid?
    assert_not_empty invitation.errors[:invited_by]
  end

  test "code uniqueness validation" do
    duplicate = OrganizationInvitation.new(
      email: "other@example.com",
      organization_id: @organization.id,
      invited_by: @staff,
    )
    duplicate.code = @invitation.code

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:code]
  end

  test "code length validation" do
    invitation = OrganizationInvitation.new(
      email: "test@example.com",
      organization_id: @organization.id,
      invited_by: @staff,
    )
    invitation.code = "x" * 33

    assert_not invitation.valid?
    assert_not_empty invitation.errors[:code]
  end

  test "active? returns true for fresh invitation" do
    assert_predicate @invitation, :active?
  end

  test "expired? returns false for fresh invitation" do
    assert_not @invitation.expired?
  end

  test "consumed? returns false for fresh invitation" do
    assert_not @invitation.consumed?
  end

  test "active? returns false when consumed" do
    @invitation.update!(consumed_at: Time.current)

    assert_not @invitation.active?
  end

  test "expired? returns true when expires_at is in the past" do
    @invitation.update!(expires_at: 1.day.ago)

    assert_predicate @invitation, :expired?
  end

  test "consumed? returns true when consumed_at is set" do
    @invitation.update!(consumed_at: Time.current)

    assert_predicate @invitation, :consumed?
  end

  test "consume! marks invitation as consumed" do
    assert @invitation.consume!

    assert_predicate @invitation, :consumed?
    assert_not @invitation.active?
  end

  test "consume! returns false for already consumed invitation" do
    @invitation.update!(consumed_at: Time.current)

    assert_not @invitation.consume!
  end

  test "consume! returns false for expired invitation" do
    @invitation.update!(expires_at: 1.day.ago)

    assert_not @invitation.consume!
  end

  test "find_valid finds active invitation by code" do
    found = OrganizationInvitation.find_valid(@invitation.code)

    assert_equal @invitation, found
  end

  test "find_valid returns nil for consumed invitation" do
    @invitation.update!(consumed_at: Time.current)

    assert_nil OrganizationInvitation.find_valid(@invitation.code)
  end

  test "find_valid returns nil for expired invitation" do
    @invitation.update!(expires_at: 1.day.ago)

    assert_nil OrganizationInvitation.find_valid(@invitation.code)
  end

  test "find_valid matches email when provided" do
    found = OrganizationInvitation.find_valid(@invitation.code, email: "invitee@example.com")

    assert_equal @invitation, found
  end

  test "find_valid returns nil when email does not match" do
    found = OrganizationInvitation.find_valid(@invitation.code, email: "other@example.com")

    assert_nil found
  end

  test "find_valid returns nil for unknown code" do
    assert_nil OrganizationInvitation.find_valid("unknown_code")
  end

  test "find_valid matches email case-insensitively" do
    found = OrganizationInvitation.find_valid(@invitation.code, email: "INVITEE@EXAMPLE.COM")

    assert_equal @invitation, found
  end

  test "active scope returns only active invitations" do
    consumed = OrganizationInvitation.create!(
      email: "consumed@example.com",
      organization_id: @organization.id,
      invited_by: @staff,
    )
    consumed.update!(consumed_at: Time.current)

    active_invitations = OrganizationInvitation.active

    assert_includes active_invitations, @invitation
    assert_not_includes active_invitations, consumed
  end

  test "expired scope returns expired invitations" do
    expired_invitation = OrganizationInvitation.create!(
      email: "expired@example.com",
      organization_id: @organization.id,
      invited_by: @staff,
    )
    expired_invitation.update!(expires_at: 1.day.ago)

    assert_includes OrganizationInvitation.expired, expired_invitation
    assert_not_includes OrganizationInvitation.expired, @invitation
  end

  test "consumed scope returns consumed invitations" do
    consumed_invitation = OrganizationInvitation.create!(
      email: "consumed@example.com",
      organization_id: @organization.id,
      invited_by: @staff,
    )
    consumed_invitation.update!(consumed_at: Time.current)

    assert_includes OrganizationInvitation.consumed, consumed_invitation
    assert_not_includes OrganizationInvitation.consumed, @invitation
  end

  test "generate_unique_code generates 32 character lowercase alphanumeric code" do
    code = OrganizationInvitation.generate_unique_code

    assert_equal 32, code.length
    assert_match(/\A[a-z0-9]{32}\z/, code)
  end

  test "generate_unique_code generates unique codes" do
    codes = 10.times.map { OrganizationInvitation.generate_unique_code }

    assert_equal codes.uniq.size, codes.size
  end

  test "invited_by association" do
    assert_equal @staff, @invitation.invited_by
  end
end
