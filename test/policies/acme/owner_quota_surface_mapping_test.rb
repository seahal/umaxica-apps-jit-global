# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::OwnerQuotaSurfaceMappingTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    ClientIdentityState.ensure_defaults!
    OperatorIdentityState.ensure_defaults!
    VisitorIdentityState.ensure_defaults!
  end

  test "maps com account quota to Visitor and Individual ownership" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    identity = VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "quota-com-individual-#{SecureRandom.hex(6)}",
      audience: "acme_com",
      source_record_id: visitor.id,
      status_id: VisitorIdentityState::ACTIVE,
    )
    individual = I18n.with_locale(:en) { Individual.create!(visitor_identity: identity, title: "Individual") }
    IndividualLifecycle.create!(individual:, state: AuthorityResourceLifecycleStateValue::ACTIVE)
    IndividualOwnership.create!(individual:, visitor:)

    policy = Acme::AccountQuotaPolicy.new(surface: :com, principal: visitor)

    assert_equal 1, policy.current_count
    assert_equal 9, policy.remaining
  end

  test "maps org account quota to Operator and Agent ownership" do
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::BOTH)
    identity = OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "quota-org-agent-#{SecureRandom.hex(6)}",
      audience: "acme_org",
      source_record_id: operator.id,
      status_id: OperatorIdentityState::ACTIVE,
    )
    agent = I18n.with_locale(:en) { Agent.create!(operator_identity: identity, title: "Agent") }
    AgentLifecycle.create!(agent:, state: AuthorityResourceLifecycleStateValue::ACTIVE)
    AgentOwnership.create!(agent:, operator:)

    policy = Acme::AccountQuotaPolicy.new(surface: :org, principal: operator)

    assert_equal 1, policy.current_count
    assert_equal 9, policy.remaining
  end

  test "maps com organization quota to Visitor and Company ownership" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    company = I18n.with_locale(:en) { Company.create!(name: "Company", title: "Company") }
    CompanyLifecycle.create!(company:, state: AuthorityResourceLifecycleStateValue::ACTIVE)
    CompanyOwnership.create!(company:, visitor:)

    policy = Acme::OrganizationQuotaPolicy.new(surface: :com, principal: visitor)

    assert_equal 1, policy.current_count
    assert_equal 1, policy.remaining
  end

  test "maps org organization quota to Operator and Bureau ownership" do
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::BOTH)
    bureau = I18n.with_locale(:en) { Bureau.create!(name: "Bureau", title: "Bureau") }
    BureauLifecycle.create!(bureau:, state: AuthorityResourceLifecycleStateValue::ACTIVE)
    BureauOwnership.create!(bureau:, operator:)

    policy = Acme::OrganizationQuotaPolicy.new(surface: :org, principal: operator)

    assert_equal 1, policy.current_count
    assert_equal 1, policy.remaining
  end
end
