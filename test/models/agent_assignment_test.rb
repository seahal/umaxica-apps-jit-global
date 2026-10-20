# typed: false
# frozen_string_literal: true

require "test_helper"

class AgentAssignmentTest < ActiveSupport::TestCase
  setup do
    OperatorIdentityState.ensure_defaults!
  end

  test "creates active assignment with public id and assigned at" do
    agent, identity = build_agent_and_identity

    assignment = AgentAssignment.create!(agent: agent, operator_identity: identity)

    assert_predicate assignment.public_id, :present?
    assert_predicate assignment.assigned_at, :present?
    assert_predicate assignment, :active?
    assert_not_predicate assignment, :revoked?
  end

  test "revoke marks assignment as revoked" do
    agent, identity = build_agent_and_identity
    assignment = AgentAssignment.create!(agent: agent, operator_identity: identity)

    assignment.revoke!(at: Time.utc(2026, 6, 27, 12, 0, 0))

    assert_predicate assignment, :revoked?
    assert_not_predicate assignment, :active?
    assert_equal Time.utc(2026, 6, 27, 12, 0, 0), assignment.revoked_at
  end

  test "rejects duplicate active assignment for the same pair" do
    agent, identity = build_agent_and_identity

    AgentAssignment.create!(agent: agent, operator_identity: identity)

    duplicate = AgentAssignment.new(agent: agent, operator_identity: identity)

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "allows a new active assignment after revoking the old one" do
    agent, identity = build_agent_and_identity

    first = AgentAssignment.create!(agent: agent, operator_identity: identity)
    first.revoke!

    second = AgentAssignment.create!(agent: agent, operator_identity: identity)

    assert_predicate second, :active?
    assert_equal 2, AgentAssignment.where(agent: agent, operator_identity: identity).count
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::AgentAssignment)
  end

  private

  def build_agent_and_identity
    identity = OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "agent-assignment-#{SecureRandom.hex(4)}",
      audience: "acme_org",
      source_record_id: SecureRandom.random_number(1_000_000) + 2000,
      status_id: OperatorIdentityState::ACTIVE,
    )
    agent = Agent.create!(operator_identity: identity, moniker: "Default Agent", title: "Agent01")
    [agent, identity]
  end
end
