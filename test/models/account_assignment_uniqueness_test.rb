# frozen_string_literal: true

require "test_helper"

class PersonaAssignmentUniquenessTest < ActiveSupport::TestCase
  test "PersonaAssignment preserves distinct pairs revoked history and raw DB refusal" do
    first_principal = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    second_principal = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
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

    first = PersonaAssignment.create!(persona_id: first_resource.id, client_identity_id: first_identity.id)
    PersonaAssignment.create!(persona_id: first_resource.id, client_identity_id: second_identity.id)
    PersonaAssignment.create!(persona_id: second_resource.id, client_identity_id: first_identity.id)
    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        PersonaAssignment.transaction(requires_new: true) do
          PersonaAssignment.new(
            persona_id: first_resource.id,
            client_identity_id: first_identity.id,
          ).save!(validate: false)
        end
      end
    assert_instance_of PG::UniqueViolation, error.cause
    now = PersonaAssignment.database_now
    2.times do
      history = PersonaAssignment.create!(
        persona_id: first_resource.id, client_identity_id: first_identity.id,
        revoked_at: now,
      )

      assert_predicate history, :revoked?
    end
    first.revoke!(at: now)
    replacement = PersonaAssignment.create!(persona_id: first_resource.id, client_identity_id: first_identity.id)

    assert_predicate replacement, :active?
  end

  test "PersonaAssignment rejects only an active duplicate pair" do
    first_principal = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    second_principal = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
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

    first = PersonaAssignment.create!(persona_id: first_resource.id, client_identity_id: first_identity.id)
    duplicate = PersonaAssignment.new(persona_id: first_resource.id, client_identity_id: first_identity.id)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:persona_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    assert_predicate duplicate, :new_record?
    duplicate.revoked_at = PersonaAssignment.database_now

    assert_predicate duplicate, :valid?
    duplicate.save!

    assert_nil first.reload.revoked_at
  end
end

class IndividualAssignmentUniquenessTest < ActiveSupport::TestCase
  test "IndividualAssignment preserves distinct pairs revoked history and raw DB refusal" do
    first_principal = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    second_principal = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
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

    first = IndividualAssignment.create!(individual_id: first_resource.id, visitor_identity_id: first_identity.id)
    IndividualAssignment.create!(individual_id: first_resource.id, visitor_identity_id: second_identity.id)
    IndividualAssignment.create!(individual_id: second_resource.id, visitor_identity_id: first_identity.id)
    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        IndividualAssignment.transaction(requires_new: true) do
          IndividualAssignment.new(
            individual_id: first_resource.id,
            visitor_identity_id: first_identity.id,
          ).save!(validate: false)
        end
      end
    assert_instance_of PG::UniqueViolation, error.cause
    now = IndividualAssignment.database_now
    2.times do
      history = IndividualAssignment.create!(
        individual_id: first_resource.id, visitor_identity_id: first_identity.id,
        revoked_at: now,
      )

      assert_predicate history, :revoked?
    end
    first.revoke!(at: now)
    replacement = IndividualAssignment.create!(
      individual_id: first_resource.id,
      visitor_identity_id: first_identity.id,
    )

    assert_predicate replacement, :active?
  end

  test "IndividualAssignment rejects only an active duplicate pair" do
    first_principal = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    second_principal = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
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

    first = IndividualAssignment.create!(individual_id: first_resource.id, visitor_identity_id: first_identity.id)
    duplicate = IndividualAssignment.new(individual_id: first_resource.id, visitor_identity_id: first_identity.id)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:individual_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    assert_predicate duplicate, :new_record?
    duplicate.revoked_at = IndividualAssignment.database_now

    assert_predicate duplicate, :valid?
    duplicate.save!

    assert_nil first.reload.revoked_at
  end
end

class AgentAssignmentUniquenessTest < ActiveSupport::TestCase
  test "AgentAssignment preserves distinct pairs revoked history and raw DB refusal" do
    first_principal = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    second_principal = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
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

    first = AgentAssignment.create!(agent_id: first_resource.id, operator_identity_id: first_identity.id)
    AgentAssignment.create!(agent_id: first_resource.id, operator_identity_id: second_identity.id)
    AgentAssignment.create!(agent_id: second_resource.id, operator_identity_id: first_identity.id)
    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        AgentAssignment.transaction(requires_new: true) do
          AgentAssignment.new(
            agent_id: first_resource.id,
            operator_identity_id: first_identity.id,
          ).save!(validate: false)
        end
      end
    assert_instance_of PG::UniqueViolation, error.cause
    now = AgentAssignment.database_now
    2.times do
      history = AgentAssignment.create!(
        agent_id: first_resource.id, operator_identity_id: first_identity.id,
        revoked_at: now,
      )

      assert_predicate history, :revoked?
    end
    first.revoke!(at: now)
    replacement = AgentAssignment.create!(agent_id: first_resource.id, operator_identity_id: first_identity.id)

    assert_predicate replacement, :active?
  end

  test "AgentAssignment rejects only an active duplicate pair" do
    first_principal = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    second_principal = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
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

    first = AgentAssignment.create!(agent_id: first_resource.id, operator_identity_id: first_identity.id)
    duplicate = AgentAssignment.new(agent_id: first_resource.id, operator_identity_id: first_identity.id)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:agent_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    assert_predicate duplicate, :new_record?
    duplicate.revoked_at = AgentAssignment.database_now

    assert_predicate duplicate, :valid?
    duplicate.save!

    assert_nil first.reload.revoked_at
  end
end
