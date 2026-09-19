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

  test "behaves the same across surfaces" do
    assert_surface_policy(:app, Enterprise, -> { create_enterprises(1) }, client)
    assert_surface_policy(:org, Bureau, -> { create_bureaus(1) }, operator)
    assert_surface_policy(:com, Company, -> { create_companies(1) }, visitor)
  end

  private

  def assert_surface_policy(surface, model_class, setup_proc, principal)
    setup_proc.call
    policy = Acme::OrganizationQuotaPolicy.new(
      surface: surface, principal: principal,
      scope: model_class.where(id: @created_organization_ids),
    )

    assert_predicate policy, :allowed?
    assert_equal 1, policy.current_count
    assert_equal 1, policy.remaining
    assert_equal model_class, policy.send(:organization_class)
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

  def create_enterprises(count)
    @created_organization_ids = []
    count.times do
      enterprise = Enterprise.create!(name: "Enterprise", title: "Enterpris")
      EnterpriseOwnership.create!(enterprise:, client: client)
      @created_organization_ids << enterprise.id
    end
  end

  def create_bureaus(count)
    @created_organization_ids = []
    count.times do
      bureau = Bureau.create!(name: "Bureau", title: "Bureau")
      BureauOwnership.create!(bureau:, operator: operator)
      @created_organization_ids << bureau.id
    end
  end

  def create_companies(count)
    @created_organization_ids = []
    count.times do
      company = Company.create!(name: "Company", title: "Company")
      CompanyOwnership.create!(company:, visitor: visitor)
      @created_organization_ids << company.id
    end
  end
end
