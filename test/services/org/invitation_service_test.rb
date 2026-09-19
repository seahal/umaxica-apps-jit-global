# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OrgInvitationServiceTest < ActiveSupport::TestCase
  setup do
    operation = -> { [0, 1, 2, 3].each { |id| OrganizationStatus.find_or_create_by!(id: id) } }
    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call

    @staff = Operator.create!(status_id: OperatorStatus::ACTIVE)
    @organization = OperatorOrganization.create!(name: "Test Org", domain: "test-org-#{SecureRandom.hex(4)}")
  end

  test "create generates a valid invitation" do
    result = OrgInvitationService.create(
      organization_id: @organization.id,
      email: "invitee@example.com",
      invited_by: @staff,
    )

    assert_predicate result, :success?
    assert_not_nil result.invitation
    assert_not_nil result.code
    assert_nil result.error

    assert_equal "invitee@example.com", result.invitation.email
    assert_equal @organization.id, result.invitation.organization_id
    assert_equal @staff.id, result.invitation.invited_by_id
  end

  test "create fails with invalid parameters" do
    result = OrgInvitationService.create(
      organization_id: nil,
      email: "invitee@example.com",
      invited_by: @staff,
    )

    assert_not result.success?
    assert_nil result.invitation
    assert_nil result.code
    assert_predicate result.error, :present?
  end

  test "validate returns success for valid code" do
    invitation = OrganizationInvitation.create!(
      organization_id: @organization.id,
      email: "invitee@example.com",
      invited_by: @staff,
    )

    result = OrgInvitationService.validate(code: invitation.code)

    assert_predicate result, :success?
    assert_equal invitation, result.invitation
    assert_nil result.error
  end

  test "validate returns failure for invalid code" do
    result = OrgInvitationService.validate(code: "invalid-code")

    assert_not result.success?
    assert_nil result.invitation
    assert_match(/Invalid or expired/, result.error)
  end

  test "validate returns failure for email mismatch" do
    invitation = OrganizationInvitation.create!(
      organization_id: @organization.id,
      email: "invitee@example.com",
      invited_by: @staff,
    )

    result = OrgInvitationService.validate(code: invitation.code, email: "other@example.com")

    assert_not result.success?
    assert_match(/Invalid or expired/, result.error)
  end

  test "consume marks invitation as consumed" do
    invitation = OrganizationInvitation.create!(
      organization_id: @organization.id,
      email: "invitee@example.com",
      invited_by: @staff,
    )

    result = OrgInvitationService.consume(code: invitation.code)

    assert_predicate result, :success?
    assert_predicate result.invitation, :consumed?
  end

  test "consume fails for invalid code" do
    result = OrgInvitationService.consume(code: "invalid-code")

    assert_not result.success?
    assert_match(/Invalid or expired/, result.error)
  end

  test "consume fails for already consumed invitation" do
    invitation = OrganizationInvitation.create!(
      organization_id: @organization.id,
      email: "invitee@example.com",
      invited_by: @staff,
      consumed_at: Time.current,
    )

    result = OrgInvitationService.consume(code: invitation.code)

    assert_not result.success?
  end

  test "consume fails when consume! returns false due to a race condition" do
    invitation = OrganizationInvitation.create!(
      organization_id: @organization.id,
      email: "invitee@example.com",
      invited_by: @staff,
    )

    OrganizationInvitation.stub(:find_valid, invitation) do
      invitation.stub(:consume!, false) do
        result = OrgInvitationService.consume(code: invitation.code)

        assert_not result.success?
        assert_equal "Failed to consume invitation", result.error
      end
    end
  end
end
