# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OrgInvitationServiceTest < ActiveSupport::TestCase
  setup do
    @staff = Operator.create!(status_id: OperatorStatus::ACTIVE)
    @organization_id = 123
  end

  test "create refuses legacy issuance before writing an invitation" do
    assert_no_difference -> { OrganizationInvitation.count } do
      result = OrgInvitationService.create(
        organization_id: @organization_id,
        email: "invitee@example.com",
        invited_by: @staff,
      )

      assert_not result.success?
      assert_nil result.invitation
      assert_nil result.code
      assert_equal "Organization invitations are unavailable pending Bureau migration", result.error
    end
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
      organization_id: @organization_id,
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
      organization_id: @organization_id,
      email: "invitee@example.com",
      invited_by: @staff,
    )

    result = OrgInvitationService.validate(code: invitation.code, email: "other@example.com")

    assert_not result.success?
    assert_match(/Invalid or expired/, result.error)
  end

  test "consume marks invitation as consumed" do
    invitation = OrganizationInvitation.create!(
      organization_id: @organization_id,
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
      organization_id: @organization_id,
      email: "invitee@example.com",
      invited_by: @staff,
      consumed_at: Time.current,
    )

    result = OrgInvitationService.consume(code: invitation.code)

    assert_not result.success?
  end

  test "consume fails when consume! returns false due to a race condition" do
    invitation = OrganizationInvitation.create!(
      organization_id: @organization_id,
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
