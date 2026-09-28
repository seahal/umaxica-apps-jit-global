# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/operator-capability-authorization.md: the capability-backed org administration policies.
class OperatorCapabilityPoliciesTest < ActiveSupport::TestCase
  setup do
    @operator = operators(:one)
    @other = operators(:two)
  end

  test "nil, client, and ungranted operator actors are denied every support and console rule" do
    [nil, clients(:one), @operator].each do |actor|
      assert_not SupportClientPolicy.new(clients(:one), user: actor).show?
      assert_not SupportVisitorPolicy.new(visitors(:reserved_visitor), user: actor).revoke_sessions?
      assert_not OrgConsolePolicy.new(:org_console, user: actor).support?
      assert_not OperatorCapabilityGrantPolicy.new(OperatorCapabilityGrant, user: actor).index?
      assert_not EnforcementCasePolicy.new(AppEnforcementCase.new, user: actor).index?
    end
  end

  test "Bureau ownership and administration, delegation, and view grants confer no platform capability" do
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    bureau = bootstrap.collective
    BureauOwnership.create!(bureau: bureau, operator: @operator) unless BureauOwnership.exists?(bureau: bureau)
    BureauAdministrationGrant.create!(bureau: bureau, operator: @operator)
    BureauDelegationGrant.create!(bureau: bureau, operator: @operator)
    BureauViewGrant.create!(bureau: bureau, operator: @operator)

    assert_not SupportClientPolicy.new(clients(:one), user: @operator).show?
    assert_not EnforcementCasePolicy.new(AppEnforcementCase.new, user: @operator).create?
    assert_not OrgConsolePolicy.new(:org_console, user: @operator).iam?
  end

  test "a revoke grant without the read grant does not allow revocation" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @other,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    assert_not SupportClientPolicy.new(clients(:one), user: @operator).revoke_sessions?
  end

  test "the client policy rejects a visitor record even when the operator holds app capabilities" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @other,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end

    assert_predicate SupportClientPolicy.new(clients(:one), user: @operator), :revoke_sessions?
    assert_not SupportClientPolicy.new(visitors(:reserved_visitor), user: @operator).show?
  end

  test "enforcement capabilities are per realm and never reach org cases" do
    OperatorCapabilityGrant.bootstrap!(
      operator: @operator,
      capabilities: OperatorCapabilityGrant::CAPABILITIES,
      ticket_id: "TEST-1",
      expires_at: 1.day.from_now,
    )

    assert_predicate EnforcementCasePolicy.new(AppEnforcementCase.new, user: @operator), :create?
    assert_predicate EnforcementCasePolicy.new(ComEnforcementCase.new, user: @operator), :release?
    %i(index? show? create? approve? release? review_appeal?).each do |rule|
      assert_not EnforcementCasePolicy.new(OrgEnforcementCase.new, user: @operator).public_send(rule),
                 "org realm #{rule} must deny"
    end
  end

  test "an operator granted only app enforcement cannot act on com cases" do
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @other,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end

    assert_predicate EnforcementCasePolicy.new(AppEnforcementCase.new, user: @operator), :create?
    assert_not EnforcementCasePolicy.new(ComEnforcementCase.new, user: @operator).create?
    assert_not EnforcementCasePolicy.new(ComEnforcementCase.new, user: @operator).index?
  end

  test "granting requires the grant capability, holding the delegated capability, and another target" do
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_GRANT].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        origin: "bootstrap",
        capability: capability,
        reason_code: "bootstrap",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @other,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    held = OperatorCapabilityGrant.new(operator: @other, capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ)
    not_held = OperatorCapabilityGrant.new(operator: @other, capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP)
    to_self = OperatorCapabilityGrant.new(operator: @operator, capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ)
    iam = OperatorCapabilityGrant.new(operator: @other, capability: OperatorCapabilityGrant::IAM_CAPABILITY_GRANT)
    unknown = OperatorCapabilityGrant.new(operator: @other, capability: "support.*")

    assert_predicate OperatorCapabilityGrantPolicy.new(held, user: @operator), :create?
    assert_not OperatorCapabilityGrantPolicy.new(not_held, user: @operator).create?
    assert_not OperatorCapabilityGrantPolicy.new(to_self, user: @operator).create?
    assert_not OperatorCapabilityGrantPolicy.new(iam, user: @operator).create?
    assert_not OperatorCapabilityGrantPolicy.new(unknown, user: @operator).create?
  end
end
