# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OrgOperatorLifecycleInvitationIssuerTest < ActiveSupport::TestCase
  fixtures :operators

  test "refuses legacy invitation even for an approved lifecycle request" do
    request = OperatorLifecycleRequest.create!(
      action: OperatorLifecycleRequest::ACTION_JOIN,
      status: OperatorLifecycleRequest::STATUS_APPROVED,
      target_email: "invitee@example.com",
      organization_id: 123,
      role_id: 7,
      requested_by_operator: operators(:one),
      approved_by_operator: operators(:two),
      approved_at: Time.current,
    )

    assert_no_difference -> { OrganizationInvitation.count } do
      result = OrgOperatorLifecycleInvitationIssuer.call(request: request, actor: operators(:two))

      assert_not result.success?
      assert_nil result.invitation
      assert_equal "Organization invitations are unavailable pending Bureau migration", result.error
    end
  end
end
