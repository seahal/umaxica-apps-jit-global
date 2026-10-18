# frozen_string_literal: true

require "test_helper"
require "json"

class AuthorityOwnerMigrationInventoryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    ClientIdentityState.ensure_defaults!
    VisitorIdentityState.ensure_defaults!
    OperatorIdentityState.ensure_defaults!
    PersonaMembershipKind.ensure_defaults! if defined?(PersonaMembershipKind)
    PersonaMembershipState.ensure_defaults! if defined?(PersonaMembershipState)
    IndividualMembershipKind.ensure_defaults! if defined?(IndividualMembershipKind)
    IndividualMembershipState.ensure_defaults! if defined?(IndividualMembershipState)
    AgentMembershipKind.ensure_defaults! if defined?(AgentMembershipKind)
    AgentMembershipState.ensure_defaults! if defined?(AgentMembershipState)
  end

  test "covers each concrete resource and never treats a legacy binding as an owner" do
    configurations = AuthorityOwnerMigrationInventory::RESOURCE_CONFIGS

    assert_equal %w(agent bureau client_persona company enterprise individual),
                 configurations.map { |configuration| configuration.fetch(:resource_kind).to_s }.sort
    assert_equal %w(app app com com org org),
                 configurations.map { |configuration| configuration.fetch(:surface).to_s }.sort

    configurations.each do |configuration|
      assert_predicate configuration.fetch(:resource_class).name, :present?
      assert_predicate configuration.fetch(:principal_class).name, :present?
      assert_not configuration.fetch(:auto_backfill)
      assert_equal :manual_review, configuration.fetch(:recommended_action)
    end
  end

  test "fixes the approved six surface-local principal-to-resource mappings" do
    mappings =
      AuthorityOwnerMigrationInventory::RESOURCE_CONFIGS.to_h do |configuration|
        key = [configuration.fetch(:surface).to_s, configuration.fetch(:resource_kind).to_s]
        value = [
          configuration.fetch(:principal_class).name,
          configuration.fetch(:resource_class).name,
          configuration.fetch(:ownership_class).name,
        ]
        [key, value]
      end

    assert_equal %w(Client ClientPersona ClientPersonaOwnership),
                 mappings.fetch(["app", "client_persona"])
    assert_equal %w(Client Enterprise EnterpriseOwnership),
                 mappings.fetch(["app", "enterprise"])
    assert_equal %w(Visitor Individual IndividualOwnership),
                 mappings.fetch(["com", "individual"])
    assert_equal %w(Visitor Company CompanyOwnership),
                 mappings.fetch(["com", "company"])
    assert_equal %w(Operator Agent AgentOwnership),
                 mappings.fetch(["org", "agent"])
    assert_equal %w(Operator Bureau BureauOwnership),
                 mappings.fetch(["org", "bureau"])
  end

  test "resolves the approved account and organization resource kinds without local remapping" do
    assert_equal :client_persona,
                 AuthorityOwnerMigrationInventory.resource_kind_for(surface: :app, category: :account)
    assert_equal :individual,
                 AuthorityOwnerMigrationInventory.resource_kind_for(surface: :com, category: :account)
    assert_equal :agent,
                 AuthorityOwnerMigrationInventory.resource_kind_for(surface: :org, category: :account)
    assert_equal :enterprise,
                 AuthorityOwnerMigrationInventory.resource_kind_for(surface: :app, category: :organization)
    assert_equal :company,
                 AuthorityOwnerMigrationInventory.resource_kind_for(surface: :com, category: :organization)
    assert_equal :bureau,
                 AuthorityOwnerMigrationInventory.resource_kind_for(surface: :org, category: :organization)
  end

  test "rejects an unsupported authority resource category" do
    assert_raises(ArgumentError) do
      AuthorityOwnerMigrationInventory.resource_kind_for(surface: :app, category: :membership)
    end
  end

  test "authority table state is explicit rather than silently treated as ready" do
    expected = %i(not_applied applied)

    assert_equal expected, AuthorityOwnerMigrationInventory::AUTHORITY_SCHEMA_STATES
    assert_raises(KeyError) do
      AuthorityOwnerMigrationInventory::AUTHORITY_TABLES.fetch(:unknown_surface)
    end
  end

  test "scoped inventory reads only the requested surface-local family" do
    result = AuthorityOwnerMigrationInventory.call(surface: :app, resource_kind: :client_persona)

    matching_count =
      result.details.count do |detail|
        detail.fetch(:surface) == :app && detail.fetch(:resource_kind) == :client_persona
      end

    assert_equal result.details.length, matching_count
    assert_equal result.details.length, result.summary.fetch(:resources_scanned)
  end

  test "call returns a JSON-serializable inventory summary for every resource kind" do
    persona = ClientPersona.create!(client_identity: active_client_identity("inv-persona"), title: "InvP")
    enterprise = Enterprise.create!(name: "Inv Enterprise", title: "InvEnt")

    result = AuthorityOwnerMigrationInventory.call
    payload = JSON.parse(result.to_json)

    assert_includes %w(not_applied applied), payload.fetch("summary").fetch("authority_schema_state")
    assert_operator payload.fetch("summary").fetch("resources_scanned"), :>=, 1
    assert_kind_of Hash, payload.fetch("summary").fetch("classifications")

    persona_detail =
      payload.fetch("details").find do |detail|
        detail.fetch("resource_kind") == "client_persona" &&
          detail.fetch("resource_public_id") == persona.public_id
      end

    assert persona_detail, "expected the inventory to list the created persona"
    assert_not persona_detail.fetch("source_is_authoritative_owner")
    assert_equal "manual_review", persona_detail.fetch("recommended_action")

    enterprise_detail =
      payload.fetch("details").find do |detail|
        detail.fetch("resource_kind") == "enterprise" &&
          detail.fetch("resource_public_id") == enterprise.public_id
      end

    assert enterprise_detail, "expected the inventory to list the created enterprise"
    assert_equal "no_legacy_owner_candidate", enterprise_detail.fetch("classification")
    assert_equal 0, enterprise_detail.fetch("active_membership_count")
  end

  test "classifies inactive identities and missing principals on every direct surface" do
    client_persona = ClientPersona.create!(
      client_identity: client_identity("inventory-inactive-client", status_id: ClientIdentityState::SUSPENDED),
      title: "IncClient",
    )
    individual = Individual.create!(
      visitor_identity: visitor_identity("inventory-inactive-visitor", status_id: VisitorIdentityState::SUSPENDED),
      title: "IncIndiv",
    )
    agent = Agent.create!(
      operator_identity: operator_identity("inventory-inactive-operator", status_id: OperatorIdentityState::SUSPENDED),
      title: "IncAgent",
    )

    missing_client_persona = ClientPersona.create!(
      client_identity: client_identity("inventory-missing-client-principal"),
      title: "MissClient",
    )
    missing_individual = Individual.create!(
      visitor_identity: visitor_identity("inventory-missing-visitor-principal"),
      title: "MissIndiv",
    )
    missing_agent = Agent.create!(
      operator_identity: operator_identity("inventory-missing-operator-principal"),
      title: "MissAgent",
    )

    payload = JSON.parse(AuthorityOwnerMigrationInventory.call.to_json)
    details = payload.fetch("details")

    assert_equal(
      "inactive_identity_binding",
      detail_for(details, "client_persona", client_persona).fetch("classification"),
    )
    assert_equal(
      "inactive_identity_binding",
      detail_for(details, "individual", individual).fetch("classification"),
    )
    assert_equal(
      "inactive_identity_binding",
      detail_for(details, "agent", agent).fetch("classification"),
    )
    assert_equal(
      "missing_principal",
      detail_for(details, "client_persona", missing_client_persona).fetch("classification"),
    )
    assert_equal(
      "missing_principal",
      detail_for(details, "individual", missing_individual).fetch("classification"),
    )
    assert_equal(
      "missing_principal",
      detail_for(details, "agent", missing_agent).fetch("classification"),
    )

    details.each do |detail|
      internal_id_keys =
        detail.keys.select do |key|
          key == "id" || key.end_with?("_record_id", "_identity_id", "_principal_id")
        end

      assert_empty(
        internal_id_keys,
        "inventory must not expose database identifiers: #{detail.inspect}",
      )
    end
  end

  test "classifies inactive principals without promoting them on every direct surface" do
    client = Client.create!(status_id: ClientStatus::INACTIVE, visibility_id: ClientVisibility::USER)
    client_persona = ClientPersona.create!(
      client_identity: ClientIdentity.create!(
        issuer: "https://id.example.test",
        subject: "inventory-inactive-client-principal",
        audience: "acme_app",
        source_record_id: client.id,
        status_id: ClientIdentityState::ACTIVE,
      ),
      title: "IncClientP",
    )

    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    individual = Individual.create!(
      visitor_identity: VisitorIdentity.create!(
        issuer: "https://id.example.test",
        subject: "inventory-inactive-visitor-principal",
        audience: "acme_com",
        source_record_id: visitor.id,
        status_id: VisitorIdentityState::ACTIVE,
      ),
      title: "IncVisP",
    )

    operator = Operator.create!(status_id: OperatorStatus::NOTHING, visibility_id: OperatorVisibility::BOTH)
    agent = Agent.create!(
      operator_identity: OperatorIdentity.create!(
        issuer: "https://id.example.test",
        subject: "inventory-inactive-operator-principal",
        audience: "acme_org",
        source_record_id: operator.id,
        status_id: OperatorIdentityState::ACTIVE,
      ),
      title: "IncOperatP",
    )

    payload = JSON.parse(AuthorityOwnerMigrationInventory.call.to_json)
    details = payload.fetch("details")

    [
      ["client_persona", client_persona],
      ["individual", individual],
      ["agent", agent],
    ].each do |resource_kind, resource|
      detail = detail_for(details, resource_kind, resource)

      assert_equal "inactive_principal", detail.fetch("classification")
      assert_not detail.fetch("source_is_authoritative_owner")
      assert_equal "manual_review", detail.fetch("recommended_action")
      assert_equal "inactive_principal", detail.fetch("candidate_principal").fetch("classification")
    end
  end

  test "keeps multiple active organization memberships as manual-review candidates" do
    first_persona = client_persona_with_active_owner("inventory-membership-one", "MemberOne")
    second_persona = client_persona_with_active_owner("inventory-membership-two", "MemberTwo")
    enterprise = Enterprise.create!(name: "Inventory Enterprise", title: "InvEnt")
    unit = EnterpriseUnit.create!(enterprise:, name: "Root")

    [first_persona, second_persona].each do |persona|
      PersonaMembership.create!(
        persona:,
        enterprise:,
        enterprise_unit: unit,
        membership_kind_id: PersonaMembershipKind::OWNER,
        membership_state_id: PersonaMembershipState::ACTIVE,
        primary: true,
      )
    end

    payload = JSON.parse(AuthorityOwnerMigrationInventory.call.to_json)
    detail = detail_for(payload.fetch("details"), "enterprise", enterprise)

    assert_equal "ambiguous_legacy_candidates", detail.fetch("classification")
    assert_equal 2, detail.fetch("active_membership_count")
    assert_equal 2, detail.fetch("candidate_principals").length
    assert_equal ["legacy_binding_candidate"],
                 detail.fetch("candidate_classifications").keys
    assert_not detail.fetch("source_is_authoritative_owner")
    assert_equal "manual_review", detail.fetch("recommended_action")
  end

  test "does not promote com or org memberships to ownership" do
    individual = individual_with_active_owner("inventory-company-member", "ComMember")
    company = Company.create!(name: "Inventory Company", title: "InvCom")
    company_unit = CompanyUnit.create!(company:, name: "Root")
    IndividualMembership.create!(
      individual:,
      company:,
      company_unit: company_unit,
      membership_kind_id: IndividualMembershipKind::OWNER,
      membership_state_id: IndividualMembershipState::ACTIVE,
      primary: true,
    )

    agent = agent_with_active_owner("inventory-bureau-member", "OrgMember")
    bureau = Bureau.create!(name: "Inventory Bureau", title: "InvBur")
    bureau_unit = BureauUnit.create!(bureau:, name: "Root")
    AgentMembership.create!(
      agent:,
      bureau:,
      bureau_unit: bureau_unit,
      membership_kind_id: AgentMembershipKind::OWNER,
      membership_state_id: AgentMembershipState::ACTIVE,
      primary: true,
    )

    payload = JSON.parse(AuthorityOwnerMigrationInventory.call.to_json)
    company_detail = detail_for(payload.fetch("details"), "company", company)
    bureau_detail = detail_for(payload.fetch("details"), "bureau", bureau)

    [company_detail, bureau_detail].each do |detail|
      assert_equal "membership_not_ownership", detail.fetch("classification")
      assert_equal 1, detail.fetch("active_membership_count")
      assert_equal ["legacy_binding_candidate"], detail.fetch("candidate_classifications").keys
      assert_not detail.fetch("source_is_authoritative_owner")
      assert_equal "manual_review", detail.fetch("recommended_action")
    end
  end

  test "classifies an administrator-only organization without promoting the administrator" do
    administrator = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    enterprise = Enterprise.create!(name: "Administrator-only Enterprise", title: "AdminOnly")
    EnterpriseAdministrationGrant.create!(enterprise:, client: administrator)

    payload = JSON.parse(AuthorityOwnerMigrationInventory.call.to_json)
    detail = detail_for(payload.fetch("details"), "enterprise", enterprise)

    assert_equal "administrator_only", detail.fetch("classification")
    assert_equal [administrator.public_id], detail.fetch("administrator_public_ids")
    assert_not detail.fetch("source_is_authoritative_owner")
    assert_equal "manual_review", detail.fetch("recommended_action")
  end

  private

  def detail_for(details, resource_kind, resource)
    details.find do |detail|
      detail.fetch("resource_kind") == resource_kind &&
        detail.fetch("resource_public_id") == resource.public_id
    end || flunk("missing inventory detail for #{resource_kind}/#{resource.public_id}")
  end

  def client_identity(label, status_id: ClientIdentityState::ACTIVE)
    ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: label,
      audience: "acme_app",
      source_record_id: Zlib.crc32(label),
      status_id:,
    )
  end

  alias active_client_identity client_identity

  def client_persona_with_active_owner(identity_label, title)
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: identity_label,
      audience: "acme_app",
      source_record_id: client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    ClientPersona.create!(client_identity: identity, title:)
  end

  def individual_with_active_owner(identity_label, title)
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    identity = VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: identity_label,
      audience: "acme_com",
      source_record_id: visitor.id,
      status_id: VisitorIdentityState::ACTIVE,
    )
    Individual.create!(visitor_identity: identity, title:)
  end

  def agent_with_active_owner(identity_label, title)
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::BOTH)
    identity = OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: identity_label,
      audience: "acme_org",
      source_record_id: operator.id,
      status_id: OperatorIdentityState::ACTIVE,
    )
    Agent.create!(operator_identity: identity, title:)
  end

  def visitor_identity(label, status_id: VisitorIdentityState::ACTIVE)
    VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: label,
      audience: "acme_com",
      source_record_id: Zlib.crc32(label),
      status_id:,
    )
  end

  def operator_identity(label, status_id: OperatorIdentityState::ACTIVE)
    OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: label,
      audience: "acme_org",
      source_record_id: Zlib.crc32(label),
      status_id:,
    )
  end
end
