# typed: false
# frozen_string_literal: true

require "test_helper"

class SurfaceResourceCreatorsTest < ActiveSupport::TestCase
  fixtures :operators

  setup do
    OperatorIdentityState.ensure_defaults!

    @operator = operators(:one)
    @operator.update!(status_id: OperatorStatus::ACTIVE)
  end

  test "creates an agent with one operator owner" do
    agent = AgentCreator.call(
      actor: @operator,
      owner: @operator,
      operator_identity: operator_identity,
      moniker: "Operator",
      title: "Operator",
    )

    assert_equal @operator.id, agent.ownership.operator_id
    assert_equal 0, agent.ownership.ownership_revision
    assert_equal AuthorityResourceLifecycleStateValue::ACTIVE, agent.lifecycle.state
    assert_empty agent.administration_grants
    assert_empty agent.delegation_grants
    assert_empty agent.usage_grants
    assert_empty agent.view_grants
  end

  test "creates a bureau with one operator owner" do
    bureau = BureauCreator.call(actor: @operator, owner: @operator, name: "Bureau", title: "Bureau")

    assert_equal @operator.id, bureau.ownership.operator_id
    assert_equal 0, bureau.ownership.ownership_revision
    assert_equal AuthorityResourceLifecycleStateValue::ACTIVE, bureau.lifecycle.state
    assert_empty bureau.administration_grants
    assert_empty bureau.delegation_grants
    assert_empty bureau.view_grants
  end

  test "rejects operator resource creation while administrative access is locked" do
    lock_operator!(@operator)

    assert_raises(AgentCreator::InactiveOwner) do
      AgentCreator.call(
        actor: @operator,
        owner: @operator,
        operator_identity: operator_identity,
        title: "Operator",
      )
    end
    assert_raises(BureauCreator::InactiveOwner) do
      BureauCreator.call(actor: @operator, owner: @operator, name: "Bureau", title: "Bureau")
    end

    assert_empty AgentOwnership.where(operator_id: @operator.id)
    assert_empty BureauOwnership.where(operator_id: @operator.id)
  end

  test "rejects non-active operator status for org resources" do
    @operator.update!(status_id: OperatorStatus::NOTHING)

    assert_raises(AgentCreator::InactiveOwner) do
      AgentCreator.call(
        actor: @operator,
        owner: @operator,
        operator_identity: operator_identity,
        moniker: "Operator",
        title: "Operator",
      )
    end
    assert_raises(BureauCreator::InactiveOwner) do
      BureauCreator.call(actor: @operator, owner: @operator, name: "Bureau", title: "Bureau")
    end
  end

  private

  def operator_identity
    OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "creator-operator-#{SecureRandom.hex(6)}",
      audience: "acme_org",
      source_record_id: @operator.id,
      status_id: OperatorIdentityState::ACTIVE,
    )
  end

  def lock_operator!(operator)
    operator.update!(
      access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
      admin_locked_at: Time.current,
      admin_locked_by_operator_id: @operator.id,
      admin_locked_reason_code: "security_incident",
    )
  end
end
