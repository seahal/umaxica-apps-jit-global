# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Acme::OrganizationQuotaPolicyTest < ActiveSupport::TestCase
  test "allows when there are no organizations" do
    policy = Acme::OrganizationQuotaPolicy.new(surface: :app, principal: client, scope: Enterprise.none)

    assert_predicate policy, :allowed?
    assert_not_predicate policy, :exceeded?
    assert_equal 2, policy.limit
    assert_equal 0, policy.current_count
    assert_equal 2, policy.remaining
  end

  test "allows when count is limit minus one" do
    create_enterprises(1)
    policy = Acme::OrganizationQuotaPolicy.new(
      surface: :app, principal: client,
      scope: Enterprise.where(id: @created_organization_ids),
    )

    assert_predicate policy, :allowed?
    assert_equal 1, policy.current_count
    assert_equal 1, policy.remaining
  end

  test "rejects when count reaches limit" do
    create_enterprises(2)
    policy = Acme::OrganizationQuotaPolicy.new(
      surface: :app, principal: client,
      scope: Enterprise.where(id: @created_organization_ids),
    )

    assert_not_predicate policy, :allowed?
    assert_predicate policy, :exceeded?
    assert_equal 0, policy.remaining
  end

  test "counts only resources owned by the principal when no scope is supplied" do
    create_enterprises(1)
    other_client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    other_enterprise = Enterprise.create!(name: "Other", title: "Other")
    EnterpriseOwnership.create!(enterprise: other_enterprise, client: other_client)
    EnterpriseLifecycle.create!(
      enterprise: other_enterprise,
      state: AuthorityResourceLifecycleStateValue::ACTIVE,
    )
    unowned_enterprise = Enterprise.create!(name: "Unowned", title: "Unowned")

    policy = Acme::OrganizationQuotaPolicy.new(surface: :app, principal: client)
    scoped_policy = Acme::OrganizationQuotaPolicy.new(
      surface: :app,
      principal: client,
      scope: Enterprise.where(id: [other_enterprise.id, unowned_enterprise.id]),
    )

    assert_equal 1, policy.current_count
    assert_equal 1, policy.remaining
    assert_equal 0, scoped_policy.current_count
  end

  test "does not count an inactive owned organization against the quota" do
    enterprise = Enterprise.create!(name: "Inactive", title: "Inactive")
    EnterpriseOwnership.create!(enterprise:, client: client)
    EnterpriseLifecycle.create!(
      enterprise:,
      state: AuthorityResourceLifecycleStateValue::INACTIVE,
    )

    policy = Acme::OrganizationQuotaPolicy.new(surface: :app, principal: client)

    assert_equal 0, policy.current_count
    assert_equal 2, policy.remaining
    assert_predicate policy, :allowed?
  end

  test "fails closed when an owned organization has no lifecycle row" do
    enterprise = Enterprise.create!(name: "Unresolved", title: "Unresolved")
    EnterpriseOwnership.create!(enterprise:, client: client)

    policy = Acme::OrganizationQuotaPolicy.new(surface: :app, principal: client)

    assert_not_predicate policy, :allowed?
    assert_equal 0, policy.remaining
  end

  test "fails closed when the principal is inactive" do
    client.update!(status_id: ClientStatus::INACTIVE)

    policy = Acme::OrganizationQuotaPolicy.new(surface: :app, principal: client)

    assert_not_predicate policy, :allowed?
    assert_equal 0, policy.remaining
  end

  private

  def client
    @client ||= Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
  end

  def create_enterprises(count)
    @created_organization_ids = []
    count.times do
      enterprise = Enterprise.create!(name: "Enterprise", title: "Enterpris")
      EnterpriseOwnership.create!(enterprise:, client: client)
      EnterpriseLifecycle.create!(
        enterprise:,
        state: AuthorityResourceLifecycleStateValue::ACTIVE,
      )
      @created_organization_ids << enterprise.id
    end
  end
end
