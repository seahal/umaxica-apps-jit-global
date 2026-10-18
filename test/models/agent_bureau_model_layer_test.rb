# typed: false
# frozen_string_literal: true

require "test_helper"

class AgentBureauModelLayerTest < ActiveSupport::TestCase
  setup do
    OperatorIdentityState.ensure_defaults!
    AgentMembershipKind.ensure_defaults!
    AgentMembershipState.ensure_defaults!
    AgentMembershipRevokeReason.ensure_defaults!
  end

  test "persona and organization concerns are included" do
    assert_includes Agent.included_modules, Persona
    assert_includes Bureau.included_modules, Organization
  end

  test "root and child unit closure rows are maintained" do
    bureau = Bureau.create!(name: "Operations", title: "Ops")
    root = BureauUnit.create!(bureau:, name: "Root")
    child = BureauUnit.create!(bureau:, parent: root, name: "Child")

    assert_equal 0, BureauUnitClosure.find_by!(ancestor: root, descendant: root).depth
    assert_equal 0, BureauUnitClosure.find_by!(ancestor: child, descendant: child).depth
    assert_equal 1, BureauUnitClosure.find_by!(ancestor: root, descendant: child).depth
    assert_equal [child], root.descendants.to_a
    assert_equal [root], child.ancestors.to_a
  end

  test "unit parent must belong to same bureau and cannot be changed" do
    first = Bureau.create!(name: "First", title: "First")
    second = Bureau.create!(name: "Second", title: "Second")
    parent = BureauUnit.create!(bureau: first, name: "Root")
    invalid = BureauUnit.new(bureau: second, parent:, name: "Invalid")

    assert_not invalid.valid?
    assert invalid.errors.of_kind?(:parent, :invalid)

    sibling = BureauUnit.create!(bureau: first, name: "Sibling")
    sibling.parent = parent

    assert_not sibling.valid?
    assert sibling.errors.of_kind?(:parent_id, :invalid)
  end

  test "membership validates bureau and active primary uniqueness" do
    agent = Agent.create!(operator_identity: operator_identity("agent-primary"), title: "Agent1")
    bureau = Bureau.create!(name: "Operations", title: "Ops")
    unit = BureauUnit.create!(bureau:, name: "Root")
    AgentMembership.create!(
      agent:,
      bureau:,
      bureau_unit: unit,
      membership_kind_id: AgentMembershipKind::OWNER,
      membership_state_id: AgentMembershipState::ACTIVE,
      primary: true,
    )

    duplicate = AgentMembership.new(
      agent:,
      bureau:,
      bureau_unit: unit,
      membership_kind_id: AgentMembershipKind::MEMBER,
      membership_state_id: AgentMembershipState::ACTIVE,
      primary: true,
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:primary, :taken)

    other_bureau = Bureau.create!(name: "Other", title: "Other")
    mismatch = AgentMembership.new(
      agent:,
      bureau: other_bureau,
      bureau_unit: unit,
      membership_kind_id: AgentMembershipKind::MEMBER,
      membership_state_id: AgentMembershipState::ACTIVE,
    )

    assert_not mismatch.valid?
    assert mismatch.errors.of_kind?(:bureau_unit, :invalid)
  end

  test "persona exposes current membership and organization protocol" do
    agent = Agent.create!(operator_identity: operator_identity("agent-interface"), title: "Agent2")
    bureau = Bureau.create!(name: "Operations", title: "Ops")
    unit = BureauUnit.create!(bureau:, name: "Root")
    membership = AgentMembership.create!(
      agent:,
      bureau:,
      bureau_unit: unit,
      membership_kind_id: AgentMembershipKind::OWNER,
      membership_state_id: AgentMembershipState::ACTIVE,
      primary: true,
    )

    assert_equal :agent_memberships, Agent.membership_association_name
    assert_equal membership, agent.primary_membership
    assert_equal membership, agent.current_membership
    assert_equal [membership], agent.current_memberships.to_a
    assert_equal bureau, agent.current_collective
    assert_equal unit, agent.current_collective_unit
    assert_equal agent, membership.account
    assert_equal bureau, membership.collective
    assert_equal unit, membership.collective_unit
    assert_predicate membership, :active?
    assert_predicate membership, :primary_active?
  end

  test "database rejects identity and bureau hierarchy integrity violations" do
    identity = operator_identity("agent-identity-unique")
    Agent.create!(operator_identity: identity, title: "Agent3")
    first = Bureau.create!(name: "First", title: "First")
    second = Bureau.create!(name: "Second", title: "Second")
    unit = BureauUnit.create!(bureau: first, name: "Root")
    agent = Agent.create!(operator_identity: operator_identity("agent-db-mismatch"), title: "Agent4")

    assert_raises(ActiveRecord::RecordNotUnique) do
      Agent.transaction(requires_new: true) do
        Agent.insert_all!(
          [
            {
              operator_identity_id: identity.id,
              public_id: "dup-#{SecureRandom.hex(8)}",
              title: "Agent3",
              created_at: Time.current,
              updated_at: Time.current,
            },
          ],
        )
      end
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      AgentMembership.transaction(requires_new: true) do
        AgentMembership.insert_all!(
          [
            {
              agent_id: agent.id,
              bureau_id: second.id,
              bureau_unit_id: unit.id,
              membership_kind_id: AgentMembershipKind::OWNER,
              membership_state_id: AgentMembershipState::ACTIVE,
              created_at: Time.current,
              updated_at: Time.current,
            },
          ],
        )
      end
    end
  end

  private

  def operator_identity(label)
    OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: label,
      audience: "acme_org",
      source_record_id: Zlib.crc32(label),
      status_id: OperatorIdentityState::ACTIVE,
    )
  end
end
