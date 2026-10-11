# typed: false
# frozen_string_literal: true

require "test_helper"

class SurfaceResourceCreatorsTest < ActiveSupport::TestCase
  fixtures :visitors, :operators

  setup do
    VisitorIdentityState.ensure_defaults!
    OperatorIdentityState.ensure_defaults!

    @visitor = visitors(:reserved_visitor)
    @visitor.update!(status_id: VisitorStatus::ACTIVE)
    @operator = operators(:one)
    @operator.update!(status_id: OperatorStatus::ACTIVE)
  end

  test "creates an individual with one visitor owner" do
    individual = IndividualCreator.call(
      actor: @visitor,
      owner: @visitor,
      visitor_identity: visitor_identity,
      moniker: "Visitor",
      title: "Visitor",
    )

    assert_equal @visitor.id, individual.ownership.visitor_id
    assert_equal 0, individual.ownership.ownership_revision
    assert_empty individual.administration_grants
    assert_empty individual.delegation_grants
    assert_empty individual.usage_grants
    assert_empty individual.view_grants
  end

  test "creates a company with one visitor owner" do
    company = CompanyCreator.call(actor: @visitor, owner: @visitor, name: "Company", title: "Company")

    assert_equal @visitor.id, company.ownership.visitor_id
    assert_equal 0, company.ownership.ownership_revision
    assert_empty company.administration_grants
    assert_empty company.delegation_grants
    assert_empty company.view_grants
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
    assert_empty agent.administration_grants
    assert_empty agent.delegation_grants
    assert_empty agent.usage_grants
    assert_empty agent.view_grants
  end

  test "creates a bureau with one operator owner" do
    bureau = BureauCreator.call(actor: @operator, owner: @operator, name: "Bureau", title: "Bureau")

    assert_equal @operator.id, bureau.ownership.operator_id
    assert_equal 0, bureau.ownership.ownership_revision
    assert_empty bureau.administration_grants
    assert_empty bureau.delegation_grants
    assert_empty bureau.view_grants
  end

  test "rejects visitor resource creation while administrative access is locked" do
    lock_visitor!(@visitor)

    assert_raises(IndividualCreator::InactiveOwner) do
      IndividualCreator.call(
        actor: @visitor,
        owner: @visitor,
        visitor_identity: visitor_identity,
        title: "Visitor",
      )
    end
    assert_raises(CompanyCreator::InactiveOwner) do
      CompanyCreator.call(actor: @visitor, owner: @visitor, name: "Company", title: "Company")
    end

    assert_empty IndividualOwnership.where(visitor_id: @visitor.id)
    assert_empty CompanyOwnership.where(visitor_id: @visitor.id)
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

  test "rejects non-active principal statuses for all surface resources" do
    @visitor.update!(status_id: VisitorStatus::NOTHING)

    assert_raises(IndividualCreator::InactiveOwner) do
      IndividualCreator.call(
        actor: @visitor,
        owner: @visitor,
        visitor_identity: visitor_identity,
        moniker: "Visitor",
        title: "Visitor",
      )
    end
    assert_raises(CompanyCreator::InactiveOwner) do
      CompanyCreator.call(actor: @visitor, owner: @visitor, name: "Company", title: "Company")
    end

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

  def visitor_identity
    VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "creator-visitor-#{SecureRandom.hex(6)}",
      audience: "acme_com",
      source_record_id: @visitor.id,
      status_id: VisitorIdentityState::ACTIVE,
    )
  end

  def operator_identity
    OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "creator-operator-#{SecureRandom.hex(6)}",
      audience: "acme_org",
      source_record_id: @operator.id,
      status_id: OperatorIdentityState::ACTIVE,
    )
  end

  def lock_visitor!(visitor)
    visitor.update!(
      access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
      admin_locked_at: Time.current,
      admin_locked_by_operator_id: @operator.id,
      admin_locked_reason_code: "security_incident",
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
