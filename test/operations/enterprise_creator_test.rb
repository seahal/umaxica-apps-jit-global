# typed: false
# frozen_string_literal: true

require "test_helper"

class EnterpriseCreatorTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    @client = clients(:one)
    @client.update!(status_id: ClientStatus::ACTIVE)
  end

  test "creates an enterprise and its single owner in one authority transaction" do
    enterprise = EnterpriseCreator.call(
      actor: @client,
      owner: @client,
      name: "Acme",
      title: "Acme",
    )

    assert_equal @client.id, enterprise.ownership.client_id
    assert_equal 0, enterprise.ownership.ownership_revision
    assert_empty enterprise.administration_grants
    assert_empty enterprise.delegation_grants
    assert_empty enterprise.view_grants
  end

  test "rejects an inactive owner" do
    @client.update!(status_id: ClientStatus::INACTIVE)

    assert_raises(EnterpriseCreator::InactiveOwner) do
      EnterpriseCreator.call(actor: @client, owner: @client, name: "Acme", title: "Acme")
    end

    assert_equal 0, EnterpriseOwnership.where(client_id: @client.id).count
  end

  test "enforces the organization ownership quota" do
    2.times do |index|
      enterprise = Enterprise.create!(name: "E#{index}", title: "E#{index}")
      EnterpriseOwnership.create!(enterprise:, client: @client)
    end

    assert_raises(EnterpriseCreator::QuotaExceeded) do
      EnterpriseCreator.call(actor: @client, owner: @client, name: "Acme", title: "Acme")
    end
  end
end
