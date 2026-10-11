# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Acme::AccountQuotaPolicyTest < ActiveSupport::TestCase
  setup do
    ClientIdentityState.ensure_defaults!
    OperatorIdentityState.ensure_defaults!
    VisitorIdentityState.ensure_defaults!
  end

  test "allows when there are no accounts" do
    policy = Acme::AccountQuotaPolicy.new(surface: :app, principal: client, scope: ClientPersona.none)

    assert_predicate policy, :allowed?
    assert_not_predicate policy, :exceeded?
    assert_equal 10, policy.limit
    assert_equal 0, policy.current_count
    assert_equal 10, policy.remaining
  end

  test "allows when count is limit minus one" do
    create_personas(9)
    policy = Acme::AccountQuotaPolicy.new(surface: :app, principal: client, scope: personas_for_client)

    assert_predicate policy, :allowed?
    assert_equal 9, policy.current_count
    assert_equal 1, policy.remaining
  end

  test "rejects when count reaches limit" do
    create_personas(10)
    policy = Acme::AccountQuotaPolicy.new(surface: :app, principal: client, scope: personas_for_client)

    assert_not_predicate policy, :allowed?
    assert_predicate policy, :exceeded?
    assert_equal 0, policy.remaining
  end

  test "counts only resources owned by the principal when no scope is supplied" do
    create_personas(1)
    other_client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    other_persona = ClientPersona.create!(client_identity: client_identity_for(other_client), title: "Other")
    ClientPersonaOwnership.create!(client_persona: other_persona, client: other_client)
    unowned_client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    unowned_persona = ClientPersona.create!(client_identity: client_identity_for(unowned_client), title: "Unowned")

    policy = Acme::AccountQuotaPolicy.new(surface: :app, principal: client)
    scoped_policy = Acme::AccountQuotaPolicy.new(
      surface: :app,
      principal: client,
      scope: ClientPersona.where(id: [other_persona.id, unowned_persona.id]),
    )

    assert_equal 1, policy.current_count
    assert_equal 9, policy.remaining
    assert_equal 0, scoped_policy.current_count
  end

  test "behaves the same across surfaces" do
    assert_surface_policy(:app, ClientPersona, -> { create_personas(1) }, client)
    assert_surface_policy(:org, Agent, -> { create_agents(1) }, operator)
    assert_surface_policy(:com, Individual, -> { create_individuals(1) }, visitor)
  end

  private

  def assert_surface_policy(surface, model_class, setup_proc, principal)
    setup_proc.call
    policy = Acme::AccountQuotaPolicy.new(
      surface: surface, principal: principal,
      scope: model_class.where(id: @created_account_ids),
    )

    assert_predicate policy, :allowed?
    assert_equal 1, policy.current_count
    assert_equal 9, policy.remaining
    assert_equal model_class, policy.send(:account_class)
  end

  def client
    @client ||= Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
  end

  def operator
    @operator ||= Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
  end

  def visitor
    @visitor ||= Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
  end

  def create_personas(count)
    @created_account_ids = []
    count.times do |index|
      persona = ClientPersona.create!(
        client_identity: client_identity("client-#{index}"),
        title: "P#{index}",
      )
      ClientPersonaOwnership.create!(client_persona: persona, client: client)
      @created_account_ids << persona.id
    end
  end

  def client_identity_for(owner)
    ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "client-quota-other-#{SecureRandom.hex(6)}",
      audience: "acme_app",
      source_record_id: owner.id,
      status_id: ClientIdentityState::ACTIVE,
    )
  end

  def personas_for_client
    ClientPersona.where(id: @created_account_ids)
  end

  def create_agents(count)
    @created_account_ids = []
    count.times {
      agent = Agent.create!(operator_identity: operator_identity, title: "A#{SecureRandom.hex(2)}")
      AgentOwnership.create!(agent:, operator: operator)
      @created_account_ids << agent.id
    }
  end

  def create_individuals(count)
    @created_account_ids = []
    count.times do
      individual = Individual.create!(
        visitor_identity: visitor_identity,
        title: "I#{SecureRandom.hex(2)}",
      )
      IndividualOwnership.create!(individual:, visitor: visitor)
      @created_account_ids << individual.id
    end
  end

  def client_identity(label = "client")
    ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "client-quota-#{label}",
      audience: "acme_app",
      source_record_id: Zlib.crc32("client-quota-#{label}"),
      status_id: ClientIdentityState::ACTIVE,
    )
  end

  def operator_identity
    @operator_identity ||= OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "operator-quota",
      audience: "acme_org",
      source_record_id: SecureRandom.random_number(1_000_000_000),
      status_id: OperatorIdentityState::ACTIVE,
    )
  end

  def visitor_identity
    @visitor_identity ||= VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "visitor-quota",
      audience: "acme_com",
      source_record_id: SecureRandom.random_number(1_000_000_000),
      status_id: VisitorIdentityState::ACTIVE,
    )
  end
end
