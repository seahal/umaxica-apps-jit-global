# frozen_string_literal: true

require "test_helper"

class AuthorityOwnerPredeploymentBackfillOperationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    ClientIdentityState.ensure_defaults!
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
  end

  test "commits the reviewed owner and lifecycle state as one idempotent unit" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "predeployment-backfill-client",
      audience: "acme_app",
      source_record_id: client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    persona = I18n.with_locale(:en) { ClientPersona.create!(client_identity: identity, title: "Reviewed") }

    first = call_for(persona, client)
    second = call_for(persona, client)

    assert_equal :applied, first.status
    assert_equal :already_applied, second.status
    assert_equal client.public_id, first.owner_public_id
    assert_equal "active", first.lifecycle_state
    assert_equal client.id, persona.reload.ownership.client_id
    assert_equal "active", persona.lifecycle.state
  end

  test "does not create a lifecycle row when the explicit owner is rejected" do
    client = Client.create!(status_id: ClientStatus::INACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "predeployment-backfill-inactive-client",
      audience: "acme_app",
      source_record_id: client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    persona = I18n.with_locale(:en) { ClientPersona.create!(client_identity: identity, title: "Inactive") }

    result = call_for(persona, client)

    assert_equal :manual_review, result.status
    assert_equal :inactive_principal, result.reason
    assert_not ClientPersonaOwnership.exists?(client_persona_id: persona.id)
    assert_not ClientPersonaLifecycle.exists?(client_persona_id: persona.id)
  end

  test "rolls back the owner when the lifecycle state conflicts" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "predeployment-backfill-lifecycle-conflict",
      audience: "acme_app",
      source_record_id: client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    persona = I18n.with_locale(:en) { ClientPersona.create!(client_identity: identity, title: "Conflict") }
    ClientPersonaLifecycle.create!(
      client_persona: persona,
      state: AuthorityResourceLifecycleStateValue::INACTIVE,
    )

    result = call_for(persona, client, lifecycle_state: AuthorityResourceLifecycleStateValue::ACTIVE)

    assert_equal :manual_review, result.status
    assert_equal :lifecycle_conflict, result.reason
    assert_not ClientPersonaOwnership.exists?(client_persona_id: persona.id)
  end

  test "applies the same reviewed contract to all six surface-local resource families" do
    VisitorIdentityState.ensure_defaults!
    VisitorStatus.ensure_defaults!
    VisitorVisibility.ensure_defaults!
    OperatorIdentityState.ensure_defaults!
    OperatorStatus.ensure_defaults!
    OperatorVisibility.ensure_defaults!

    cases = [
      reviewed_client_persona_case,
      reviewed_enterprise_case,
      reviewed_individual_case,
      reviewed_company_case,
      reviewed_agent_case,
      reviewed_bureau_case,
    ]

    cases.each do |entry|
      result =
        AuthorityOwnerPredeploymentBackfillOperation.call(
          **entry.slice(
            :surface,
            :resource_kind,
            :resource_public_id,
            :owner_public_id,
            :lifecycle_state,
          ),
        )

      assert_equal :applied, result.status, entry.fetch(:resource_kind)
      assert_equal "active", result.lifecycle_state
      assert_equal entry.fetch(:owner_public_id), result.owner_public_id
    end
  end

  private

  def call_for(persona, client, lifecycle_state: AuthorityResourceLifecycleStateValue::ACTIVE)
    AuthorityOwnerPredeploymentBackfillOperation.call(
      surface: :app,
      resource_kind: :client_persona,
      resource_public_id: persona.public_id,
      owner_public_id: client.public_id,
      lifecycle_state:,
    )
  end

  def reviewed_client_persona_case
    owner = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "all-six-client-persona",
      audience: "acme_app",
      source_record_id: owner.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    resource = I18n.with_locale(:en) { ClientPersona.create!(client_identity: identity, title: "Persona") }
    reviewed_case(:app, :client_persona, resource, owner)
  end

  def reviewed_enterprise_case
    owner = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    resource = I18n.with_locale(:en) { Enterprise.create!(name: "Enterprise", title: "Enterprise") }
    reviewed_case(:app, :enterprise, resource, owner)
  end

  def reviewed_individual_case
    owner = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    identity = VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "all-six-individual",
      audience: "acme_com",
      source_record_id: owner.id,
      status_id: VisitorIdentityState::ACTIVE,
    )
    resource = I18n.with_locale(:en) { Individual.create!(visitor_identity: identity, title: "Individual") }
    reviewed_case(:com, :individual, resource, owner)
  end

  def reviewed_company_case
    owner = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    resource = I18n.with_locale(:en) { Company.create!(name: "Company", title: "Company") }
    reviewed_case(:com, :company, resource, owner)
  end

  def reviewed_agent_case
    owner = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::BOTH)
    identity = OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "all-six-agent",
      audience: "acme_org",
      source_record_id: owner.id,
      status_id: OperatorIdentityState::ACTIVE,
    )
    resource = I18n.with_locale(:en) { Agent.create!(operator_identity: identity, title: "Agent") }
    reviewed_case(:org, :agent, resource, owner)
  end

  def reviewed_bureau_case
    owner = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::BOTH)
    resource = I18n.with_locale(:en) { Bureau.create!(name: "Bureau", title: "Bureau") }
    reviewed_case(:org, :bureau, resource, owner)
  end

  def reviewed_case(surface, resource_kind, resource, owner)
    {
      surface:,
      resource_kind:,
      resource_public_id: resource.public_id,
      owner_public_id: owner.public_id,
      lifecycle_state: AuthorityResourceLifecycleStateValue::ACTIVE,
    }
  end
end
