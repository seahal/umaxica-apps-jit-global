# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientPersonaCreatorTest < ActiveSupport::TestCase
  class RollbackProbe < StandardError; end

  fixtures :operators

  setup do
    ClientIdentityState.ensure_defaults!
    @client = create_test_client
  end

  test "creates one ownership row for the authenticated client without grants" do
    identity = client_identity

    persona = ClientPersonaCreator.call(
      actor: @client,
      owner: @client,
      client_identity: identity,
      moniker: "Personal",
      title: "Primary",
    )

    assert_equal @client.id, persona.ownership.client_id
    assert_equal 0, persona.ownership.ownership_revision
    assert_empty persona.administration_grants
    assert_empty persona.delegation_grants
    assert_empty persona.usage_grants
    assert_empty persona.view_grants
  end

  test "rolls back principal and authority writes on the shared app writer" do
    identity = client_identity(label: "rollback")
    original_status_id = @client.status_id

    assert_raises(RollbackProbe) do
      AppZenithRecord.transaction do
        @client.update!(status_id: ClientStatus::INACTIVE)
        persona = ClientPersona.create!(client_identity: identity, title: "Rollback")
        ClientPersonaOwnership.create!(
          client_persona: persona,
          client: @client,
          ownership_revision: 0,
        )
        raise RollbackProbe, "test transaction rollback"
      end
    end

    assert_equal original_status_id, Client.find(@client.id).status_id
    assert_nil ClientPersona.find_by(client_identity_id: identity.id)
    assert_empty ClientPersonaOwnership.where(client_id: @client.id)
  end

  test "rejects a client identity belonging to another client" do
    other = create_test_client

    assert_raises(ClientPersonaCreator::IdentityMismatch) do
      ClientPersonaCreator.call(
        actor: @client,
        owner: @client,
        client_identity: client_identity(source_record_id: other.id),
        title: "Primary",
      )
    end

    assert_equal 0, ClientPersonaOwnership.where(client_id: @client.id).count
  end

  test "rejects an inactive actor before writing authority state" do
    @client.update!(status_id: ClientStatus::INACTIVE)

    assert_raises(ClientPersonaCreator::InactiveOwner) do
      ClientPersonaCreator.call(
        actor: @client,
        owner: @client,
        client_identity: client_identity,
        title: "Primary",
      )
    end

    assert_equal 0, ClientPersonaOwnership.where(client_id: @client.id).count
  end

  test "rejects an owner blocked by an administrative access lock" do
    @client.update!(
      access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
      admin_locked_at: Time.current,
      admin_locked_by_operator_id: operators(:one).id,
      admin_locked_reason_code: "security_incident",
    )

    assert_raises(ClientPersonaCreator::InactiveOwner) do
      ClientPersonaCreator.call(
        actor: @client,
        owner: @client,
        client_identity: client_identity,
        title: "Primary",
      )
    end

    assert_equal 0, ClientPersonaOwnership.where(client_id: @client.id).count
  end

  test "enforces the persona ownership quota" do
    10.times do |index|
      persona = ClientPersona.create!(
        client_identity: client_identity_for_another_client(label: "existing-#{index}"),
        title: "P#{index}",
      )
      ClientPersonaOwnership.create!(client_persona: persona, client: @client)
    end

    assert_raises(ClientPersonaCreator::QuotaExceeded) do
      ClientPersonaCreator.call(
        actor: @client,
        owner: @client,
        client_identity: client_identity(label: "over-quota"),
        title: "Primary",
      )
    end
  end

  private

  def client_identity(source_record_id: @client.id, label: SecureRandom.hex(6))
    ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "creator-#{label}",
      audience: "acme_app",
      source_record_id:,
      status_id: ClientIdentityState::ACTIVE,
    )
  end

  def client_identity_for_another_client(label:)
    resource_client = create_test_client
    client_identity(source_record_id: resource_client.id, label:)
  end

  def create_test_client
    Client.create!(id: unique_client_id, status_id: ClientStatus::ACTIVE)
  end

  def unique_client_id
    loop do
      candidate = 2_000_000_000 + SecureRandom.random_number(100_000_000)
      next if Client.exists?(id: candidate)
      next if ClientIdentity.exists?(source_record_id: candidate)

      break candidate
    end
  end
end
