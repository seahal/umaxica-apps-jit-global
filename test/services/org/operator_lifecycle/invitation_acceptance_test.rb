# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgOperatorLifecycleInvitationAcceptanceTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses, :operator_email_statuses, :operator_visibilities

  setup do
    @invitation = OrganizationInvitation.create!(
      organization_id: 123,
      email: "invitee@example.com",
      invited_by: operators(:one),
      role_id: 7,
    )
  end

  test "legacy target is refused without provisioning or consuming on repeated acceptance" do
    counts = [Operator.count, OperatorEmail.count, OperatorAccount.count, OperatorIdentity.count,
              Agent.count, Bureau.count, BureauUnit.count, AgentAssignment.count, AgentMembership.count,]

    2.times do
      result = OrgOperatorLifecycleInvitationAcceptance.call(invitation_code: @invitation.code)

      assert_not result.success?
      assert_equal "Organization invitations are unavailable pending Bureau migration", result.error
      assert_equal @invitation, result.invitation
      assert_nil result.operator
      assert_nil result.email
      assert_not_predicate @invitation.reload, :consumed?
      assert_equal counts, [Operator.count, OperatorEmail.count, OperatorAccount.count, OperatorIdentity.count,
                            Agent.count, Bureau.count, BureauUnit.count, AgentAssignment.count, AgentMembership.count,]
    end
  end

  test "coincident Bureau id does not establish a legacy target mapping" do
    bureau = Bureau.create!(id: @invitation.organization_id, name: "Unrelated Bureau", title: "Org01")

    assert_no_difference -> { AgentMembership.count } do
      result = OrgOperatorLifecycleInvitationAcceptance.call(invitation_code: @invitation.code)

      assert_not result.success?
      assert_equal "Organization invitations are unavailable pending Bureau migration", result.error
    end
    assert_empty bureau.agent_memberships
    assert_not_predicate @invitation.reload, :consumed?
  end

  test "existing operator email does not authorize joining a Bureau" do
    operators(:two).operator_emails.create!(
      raw_address: @invitation.email,
      confirm_policy: true,
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )

    assert_no_difference [-> { Operator.count }, -> { OperatorEmail.count }, -> { AgentMembership.count }] do
      result = OrgOperatorLifecycleInvitationAcceptance.call(invitation_code: @invitation.code)

      assert_not result.success?
      assert_equal "Organization invitations are unavailable pending Bureau migration", result.error
    end
    assert_not_predicate @invitation.reload, :consumed?
  end

  test "missing empty and unknown codes fail before provisioning" do
    [nil, "", "missing"].each do |code|
      assert_no_difference [-> { Operator.count }, -> { AgentMembership.count }] do
        result = OrgOperatorLifecycleInvitationAcceptance.call(invitation_code: code)

        assert_not result.success?
        assert_includes ["Invitation code is required", "Invalid invitation code"], result.error
      end
    end
  end

  test "consumed invitation preserves its failure and stored consumption" do
    @invitation.update!(consumed_at: Time.current)
    consumed_at = @invitation.reload.consumed_at

    assert_no_difference -> { Operator.count } do
      result = OrgOperatorLifecycleInvitationAcceptance.call(invitation_code: @invitation.code)

      assert_not result.success?
      assert_equal "Invitation has already been used", result.error
    end
    assert_equal consumed_at, @invitation.reload.consumed_at
  end

  test "expiry immediately below at and above deadline never admits a legacy target" do
    deadline = Time.current.change(usec: 0) + 1.hour
    @invitation.update!(expires_at: deadline)

    [deadline - Rational(1, 1_000_000), deadline, deadline + Rational(1, 1_000_000)].each do |now|
      travel_to now, with_usec: true do
        assert_no_difference [-> { Operator.count }, -> { AgentMembership.count }] do
          result = OrgOperatorLifecycleInvitationAcceptance.call(invitation_code: @invitation.code)

          assert_not result.success?
          expected =
            if now < deadline
              "Organization invitations are unavailable pending Bureau migration"
            else
              "Invitation has expired"
            end

          assert_equal expected, result.error
        end
        assert_not_predicate @invitation.reload, :consumed?
      end
    end
  end
end
