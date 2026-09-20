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

  private

  def client
    @client ||= Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
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

  def client_identity(label = "client")
    ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "client-quota-#{label}",
      audience: "acme_app",
      source_record_id: Zlib.crc32("client-quota-#{label}"),
      status_id: ClientIdentityState::ACTIVE,
    )
  end
end
