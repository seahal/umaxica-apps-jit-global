# frozen_string_literal: true

require "test_helper"

class EnterprisePendingTransferUniquenessTest < ActiveSupport::TestCase
  test "EnterpriseOwnershipTransferRequest preserves closed history resource scope and SQL uniqueness" do
    first_principal = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
    )
    second_principal = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
    )
    first_resource = Enterprise.create!(name: "First resource", title: "First")
    second_resource = Enterprise.create!(name: "Second resource", title: "Second")

    attributes = { enterprise_id: first_resource.id,
                   source_client_id: first_principal.id,
                   destination_client_id: second_principal.id,
                   expected_ownership_revision: 0,
                   requested_at: Time.utc(2026, 1, 1),
                   expires_at: Time.utc(2026, 1, 1, 1),
                   status: "pending", }
    first = EnterpriseOwnershipTransferRequest.create!(attributes)
    ["cancelled", "expired"].each do |status|
      history = EnterpriseOwnershipTransferRequest.create!(attributes.merge(status: status))

      assert_equal status, history.reload.status
    end
    other = EnterpriseOwnershipTransferRequest.create!(attributes.merge(enterprise_id: second_resource.id))

    assert_predicate other, :persisted?
    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        EnterpriseOwnershipTransferRequest.transaction(requires_new: true) {
          EnterpriseOwnershipTransferRequest.new(attributes).save!(validate: false)
        }
      end
    assert_instance_of PG::UniqueViolation, error.cause
    first.update!(status: "cancelled", cancelled_at: Time.utc(2026, 1, 1, 0, 30))
    replacement = EnterpriseOwnershipTransferRequest.create!(attributes)

    assert_equal "pending", replacement.reload.status
  end

  test "EnterpriseOwnershipTransferRequest rejects pending duplicates before SQL" do
    first_principal = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
    )
    second_principal = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
    )
    first_resource = Enterprise.create!(name: "First resource", title: "First")
    Enterprise.create!(name: "Second resource", title: "Second")

    attributes = { enterprise_id: first_resource.id,
                   source_client_id: first_principal.id,
                   destination_client_id: second_principal.id,
                   expected_ownership_revision: 0,
                   requested_at: Time.utc(2026, 1, 1),
                   expires_at: Time.utc(2026, 1, 1, 1),
                   status: "pending", }
    first = EnterpriseOwnershipTransferRequest.create!(attributes)
    duplicate = EnterpriseOwnershipTransferRequest.new(attributes)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:enterprise_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    assert_predicate duplicate, :new_record?
    duplicate.status = "cancelled"

    assert_predicate duplicate, :valid?
    duplicate.save!

    assert_equal "pending", first.reload.status
  end
end

class ClientPersonaPendingTransferUniquenessTest < ActiveSupport::TestCase
  test "ClientPersonaOwnershipTransferRequest preserves closed history resource scope and SQL uniqueness" do
    first_principal = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
    )
    second_principal = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
    )
    ClientIdentityState.ensure_defaults!
    first_identity = ClientIdentity.create!(
      issuer: "https://grants.example.test", subject: "first",
      audience: "acme_app", source_record_id: first_principal.id, status_id: ClientIdentityState::ACTIVE,
    )
    second_identity = ClientIdentity.create!(
      issuer: "https://grants.example.test", subject: "second",
      audience: "acme_app", source_record_id: second_principal.id, status_id: ClientIdentityState::ACTIVE,
    )
    first_resource = ClientPersona.create!(client_identity: first_identity, title: "First")
    second_resource = ClientPersona.create!(client_identity: second_identity, title: "Second")

    attributes = { client_persona_id: first_resource.id,
                   source_client_id: first_principal.id,
                   destination_client_id: second_principal.id,
                   expected_ownership_revision: 0,
                   requested_at: Time.utc(2026, 1, 1),
                   expires_at: Time.utc(2026, 1, 1, 1),
                   status: "pending", }
    first = ClientPersonaOwnershipTransferRequest.create!(attributes)
    ["cancelled", "expired"].each do |status|
      history = ClientPersonaOwnershipTransferRequest.create!(attributes.merge(status: status))

      assert_equal status, history.reload.status
    end
    other = ClientPersonaOwnershipTransferRequest.create!(attributes.merge(client_persona_id: second_resource.id))

    assert_predicate other, :persisted?
    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        ClientPersonaOwnershipTransferRequest.transaction(requires_new: true) {
          ClientPersonaOwnershipTransferRequest.new(attributes).save!(validate: false)
        }
      end
    assert_instance_of PG::UniqueViolation, error.cause
    first.update!(status: "cancelled", cancelled_at: Time.utc(2026, 1, 1, 0, 30))
    replacement = ClientPersonaOwnershipTransferRequest.create!(attributes)

    assert_equal "pending", replacement.reload.status
  end

  test "ClientPersonaOwnershipTransferRequest rejects pending duplicates before SQL" do
    first_principal = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
    )
    second_principal = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
    )
    ClientIdentityState.ensure_defaults!
    first_identity = ClientIdentity.create!(
      issuer: "https://grants.example.test", subject: "first",
      audience: "acme_app", source_record_id: first_principal.id, status_id: ClientIdentityState::ACTIVE,
    )
    second_identity = ClientIdentity.create!(
      issuer: "https://grants.example.test", subject: "second",
      audience: "acme_app", source_record_id: second_principal.id, status_id: ClientIdentityState::ACTIVE,
    )
    first_resource = ClientPersona.create!(client_identity: first_identity, title: "First")
    ClientPersona.create!(client_identity: second_identity, title: "Second")

    attributes = { client_persona_id: first_resource.id,
                   source_client_id: first_principal.id,
                   destination_client_id: second_principal.id,
                   expected_ownership_revision: 0,
                   requested_at: Time.utc(2026, 1, 1),
                   expires_at: Time.utc(2026, 1, 1, 1),
                   status: "pending", }
    first = ClientPersonaOwnershipTransferRequest.create!(attributes)
    duplicate = ClientPersonaOwnershipTransferRequest.new(attributes)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:client_persona_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    assert_predicate duplicate, :new_record?
    duplicate.status = "cancelled"

    assert_predicate duplicate, :valid?
    duplicate.save!

    assert_equal "pending", first.reload.status
  end
end

class CompanyPendingTransferUniquenessTest < ActiveSupport::TestCase
  test "CompanyOwnershipTransferRequest preserves closed history resource scope and SQL uniqueness" do
    first_principal = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
    )
    second_principal = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
    )
    first_resource = Company.create!(name: "First resource", title: "First")
    second_resource = Company.create!(name: "Second resource", title: "Second")

    attributes = { company_id: first_resource.id,
                   source_visitor_id: first_principal.id,
                   destination_visitor_id: second_principal.id,
                   expected_ownership_revision: 0,
                   requested_at: Time.utc(2026, 1, 1),
                   expires_at: Time.utc(2026, 1, 1, 1),
                   status: "pending", }
    first = CompanyOwnershipTransferRequest.create!(attributes)
    ["cancelled", "expired"].each do |status|
      history = CompanyOwnershipTransferRequest.create!(attributes.merge(status: status))

      assert_equal status, history.reload.status
    end
    other = CompanyOwnershipTransferRequest.create!(attributes.merge(company_id: second_resource.id))

    assert_predicate other, :persisted?
    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        CompanyOwnershipTransferRequest.transaction(requires_new: true) {
          CompanyOwnershipTransferRequest.new(attributes).save!(validate: false)
        }
      end
    assert_instance_of PG::UniqueViolation, error.cause
    first.update!(status: "cancelled", cancelled_at: Time.utc(2026, 1, 1, 0, 30))
    replacement = CompanyOwnershipTransferRequest.create!(attributes)

    assert_equal "pending", replacement.reload.status
  end

  test "CompanyOwnershipTransferRequest rejects pending duplicates before SQL" do
    first_principal = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
    )
    second_principal = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
    )
    first_resource = Company.create!(name: "First resource", title: "First")
    Company.create!(name: "Second resource", title: "Second")

    attributes = { company_id: first_resource.id,
                   source_visitor_id: first_principal.id,
                   destination_visitor_id: second_principal.id,
                   expected_ownership_revision: 0,
                   requested_at: Time.utc(2026, 1, 1),
                   expires_at: Time.utc(2026, 1, 1, 1),
                   status: "pending", }
    first = CompanyOwnershipTransferRequest.create!(attributes)
    duplicate = CompanyOwnershipTransferRequest.new(attributes)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:company_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    assert_predicate duplicate, :new_record?
    duplicate.status = "cancelled"

    assert_predicate duplicate, :valid?
    duplicate.save!

    assert_equal "pending", first.reload.status
  end
end

class IndividualPendingTransferUniquenessTest < ActiveSupport::TestCase
  test "IndividualOwnershipTransferRequest preserves closed history resource scope and SQL uniqueness" do
    first_principal = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
    )
    second_principal = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
    )
    VisitorIdentityState.ensure_defaults!
    first_identity = VisitorIdentity.create!(
      issuer: "https://grants.example.test", subject: "first",
      audience: "acme_com", source_record_id: first_principal.id, status_id: VisitorIdentityState::ACTIVE,
    )
    second_identity = VisitorIdentity.create!(
      issuer: "https://grants.example.test", subject: "second",
      audience: "acme_com", source_record_id: second_principal.id, status_id: VisitorIdentityState::ACTIVE,
    )
    first_resource = Individual.create!(visitor_identity: first_identity, title: "First")
    second_resource = Individual.create!(visitor_identity: second_identity, title: "Second")

    attributes = { individual_id: first_resource.id,
                   source_visitor_id: first_principal.id,
                   destination_visitor_id: second_principal.id,
                   expected_ownership_revision: 0,
                   requested_at: Time.utc(2026, 1, 1),
                   expires_at: Time.utc(2026, 1, 1, 1),
                   status: "pending", }
    first = IndividualOwnershipTransferRequest.create!(attributes)
    ["cancelled", "expired"].each do |status|
      history = IndividualOwnershipTransferRequest.create!(attributes.merge(status: status))

      assert_equal status, history.reload.status
    end
    other = IndividualOwnershipTransferRequest.create!(attributes.merge(individual_id: second_resource.id))

    assert_predicate other, :persisted?
    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        IndividualOwnershipTransferRequest.transaction(requires_new: true) {
          IndividualOwnershipTransferRequest.new(attributes).save!(validate: false)
        }
      end
    assert_instance_of PG::UniqueViolation, error.cause
    first.update!(status: "cancelled", cancelled_at: Time.utc(2026, 1, 1, 0, 30))
    replacement = IndividualOwnershipTransferRequest.create!(attributes)

    assert_equal "pending", replacement.reload.status
  end

  test "IndividualOwnershipTransferRequest rejects pending duplicates before SQL" do
    first_principal = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
    )
    second_principal = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
    )
    VisitorIdentityState.ensure_defaults!
    first_identity = VisitorIdentity.create!(
      issuer: "https://grants.example.test", subject: "first",
      audience: "acme_com", source_record_id: first_principal.id, status_id: VisitorIdentityState::ACTIVE,
    )
    second_identity = VisitorIdentity.create!(
      issuer: "https://grants.example.test", subject: "second",
      audience: "acme_com", source_record_id: second_principal.id, status_id: VisitorIdentityState::ACTIVE,
    )
    first_resource = Individual.create!(visitor_identity: first_identity, title: "First")
    Individual.create!(visitor_identity: second_identity, title: "Second")

    attributes = { individual_id: first_resource.id,
                   source_visitor_id: first_principal.id,
                   destination_visitor_id: second_principal.id,
                   expected_ownership_revision: 0,
                   requested_at: Time.utc(2026, 1, 1),
                   expires_at: Time.utc(2026, 1, 1, 1),
                   status: "pending", }
    first = IndividualOwnershipTransferRequest.create!(attributes)
    duplicate = IndividualOwnershipTransferRequest.new(attributes)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:individual_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    assert_predicate duplicate, :new_record?
    duplicate.status = "cancelled"

    assert_predicate duplicate, :valid?
    duplicate.save!

    assert_equal "pending", first.reload.status
  end
end

class BureauPendingTransferUniquenessTest < ActiveSupport::TestCase
  test "BureauOwnershipTransferRequest preserves closed history resource scope and SQL uniqueness" do
    first_principal = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    second_principal = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    first_resource = Bureau.create!(name: "First resource", title: "First")
    second_resource = Bureau.create!(name: "Second resource", title: "Second")

    attributes = { bureau_id: first_resource.id,
                   source_operator_id: first_principal.id,
                   destination_operator_id: second_principal.id,
                   expected_ownership_revision: 0,
                   requested_at: Time.utc(2026, 1, 1),
                   expires_at: Time.utc(2026, 1, 1, 1),
                   status: "pending", }
    first = BureauOwnershipTransferRequest.create!(attributes)
    ["cancelled", "expired"].each do |status|
      history = BureauOwnershipTransferRequest.create!(attributes.merge(status: status))

      assert_equal status, history.reload.status
    end
    other = BureauOwnershipTransferRequest.create!(attributes.merge(bureau_id: second_resource.id))

    assert_predicate other, :persisted?
    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        BureauOwnershipTransferRequest.transaction(requires_new: true) {
          BureauOwnershipTransferRequest.new(attributes).save!(validate: false)
        }
      end
    assert_instance_of PG::UniqueViolation, error.cause
    first.update!(status: "cancelled", cancelled_at: Time.utc(2026, 1, 1, 0, 30))
    replacement = BureauOwnershipTransferRequest.create!(attributes)

    assert_equal "pending", replacement.reload.status
  end

  test "BureauOwnershipTransferRequest rejects pending duplicates before SQL" do
    first_principal = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    second_principal = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    first_resource = Bureau.create!(name: "First resource", title: "First")
    Bureau.create!(name: "Second resource", title: "Second")

    attributes = { bureau_id: first_resource.id,
                   source_operator_id: first_principal.id,
                   destination_operator_id: second_principal.id,
                   expected_ownership_revision: 0,
                   requested_at: Time.utc(2026, 1, 1),
                   expires_at: Time.utc(2026, 1, 1, 1),
                   status: "pending", }
    first = BureauOwnershipTransferRequest.create!(attributes)
    duplicate = BureauOwnershipTransferRequest.new(attributes)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:bureau_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    assert_predicate duplicate, :new_record?
    duplicate.status = "cancelled"

    assert_predicate duplicate, :valid?
    duplicate.save!

    assert_equal "pending", first.reload.status
  end
end

class AgentPendingTransferUniquenessTest < ActiveSupport::TestCase
  test "AgentOwnershipTransferRequest preserves closed history resource scope and SQL uniqueness" do
    first_principal = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    second_principal = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    OperatorIdentityState.ensure_defaults!
    first_identity = OperatorIdentity.create!(
      issuer: "https://grants.example.test", subject: "first",
      audience: "acme_org", source_record_id: first_principal.id, status_id: OperatorIdentityState::ACTIVE,
    )
    second_identity = OperatorIdentity.create!(
      issuer: "https://grants.example.test", subject: "second",
      audience: "acme_org", source_record_id: second_principal.id, status_id: OperatorIdentityState::ACTIVE,
    )
    first_resource = Agent.create!(operator_identity: first_identity, title: "First")
    second_resource = Agent.create!(operator_identity: second_identity, title: "Second")

    attributes = { agent_id: first_resource.id,
                   source_operator_id: first_principal.id,
                   destination_operator_id: second_principal.id,
                   expected_ownership_revision: 0,
                   requested_at: Time.utc(2026, 1, 1),
                   expires_at: Time.utc(2026, 1, 1, 1),
                   status: "pending", }
    first = AgentOwnershipTransferRequest.create!(attributes)
    ["cancelled", "expired"].each do |status|
      history = AgentOwnershipTransferRequest.create!(attributes.merge(status: status))

      assert_equal status, history.reload.status
    end
    other = AgentOwnershipTransferRequest.create!(attributes.merge(agent_id: second_resource.id))

    assert_predicate other, :persisted?
    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        AgentOwnershipTransferRequest.transaction(requires_new: true) {
          AgentOwnershipTransferRequest.new(attributes).save!(validate: false)
        }
      end
    assert_instance_of PG::UniqueViolation, error.cause
    first.update!(status: "cancelled", cancelled_at: Time.utc(2026, 1, 1, 0, 30))
    replacement = AgentOwnershipTransferRequest.create!(attributes)

    assert_equal "pending", replacement.reload.status
  end

  test "AgentOwnershipTransferRequest rejects pending duplicates before SQL" do
    first_principal = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    second_principal = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    OperatorIdentityState.ensure_defaults!
    first_identity = OperatorIdentity.create!(
      issuer: "https://grants.example.test", subject: "first",
      audience: "acme_org", source_record_id: first_principal.id, status_id: OperatorIdentityState::ACTIVE,
    )
    second_identity = OperatorIdentity.create!(
      issuer: "https://grants.example.test", subject: "second",
      audience: "acme_org", source_record_id: second_principal.id, status_id: OperatorIdentityState::ACTIVE,
    )
    first_resource = Agent.create!(operator_identity: first_identity, title: "First")
    Agent.create!(operator_identity: second_identity, title: "Second")

    attributes = { agent_id: first_resource.id,
                   source_operator_id: first_principal.id,
                   destination_operator_id: second_principal.id,
                   expected_ownership_revision: 0,
                   requested_at: Time.utc(2026, 1, 1),
                   expires_at: Time.utc(2026, 1, 1, 1),
                   status: "pending", }
    first = AgentOwnershipTransferRequest.create!(attributes)
    duplicate = AgentOwnershipTransferRequest.new(attributes)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:agent_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    assert_predicate duplicate, :new_record?
    duplicate.status = "cancelled"

    assert_predicate duplicate, :valid?
    duplicate.save!

    assert_equal "pending", first.reload.status
  end
end
