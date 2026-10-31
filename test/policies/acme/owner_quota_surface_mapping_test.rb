# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::OwnerQuotaSurfaceMappingTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    ClientIdentityState.ensure_defaults!
    OperatorIdentityState.ensure_defaults!
  end

  test "maps org account quota to Operator and Agent ownership" do
    operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::BOTH,
    )
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

  test "maps org organization quota to Operator and Bureau ownership" do
    operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::BOTH,
    )
    bureau = I18n.with_locale(:en) { Bureau.create!(name: "Bureau", title: "Bureau") }
    BureauLifecycle.create!(bureau:, state: AuthorityResourceLifecycleStateValue::ACTIVE)
    BureauOwnership.create!(bureau:, operator:)

    policy = Acme::OrganizationQuotaPolicy.new(surface: :org, principal: operator)

    assert_equal 1, policy.current_count
    assert_equal 1, policy.remaining
  end
end
