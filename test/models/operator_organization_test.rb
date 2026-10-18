# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: organizations
# Database name: org_principal
#
#  id                  :bigint           not null, primary key
#  domain              :string           default(""), not null
#  name                :string           default(""), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  department_id       :bigint
#  operator_id         :bigint
#  parent_id           :bigint
#  workspace_status_id :bigint           default(0), not null
#
# Indexes
#
#  index_organizations_on_department_id        (department_id)
#  index_organizations_on_domain               (domain) UNIQUE
#  index_organizations_on_operator_id          (operator_id)
#  index_organizations_on_parent_id            (parent_id)
#  index_organizations_on_workspace_status_id  (workspace_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (workspace_status_id => organization_statuses.id)
#
require "test_helper"

class OperatorOrganizationTest < ActiveSupport::TestCase
  setup do
    Prosopite.pause do
      [0, 1, 2, 3].each { |id| OrganizationStatus.find_or_create_by!(id: id) }
    end
  end

  test "requires name" do
    organization = OperatorOrganization.new(domain: "org-#{SecureRandom.hex(4)}")

    assert_invalid_attribute(organization, :name)
  end

  test "requires domain" do
    organization = OperatorOrganization.new(name: "Test Org")

    assert_invalid_attribute(organization, :domain)
  end

  test "accepts valid organization attributes" do
    organization = OperatorOrganization.new(
      name: "Test Org",
      domain: "test-org-#{SecureRandom.hex(4)}",
      workspace_status_id: OrganizationStatus::NOTHING,
    )

    assert_predicate organization, :valid?
  end
  private

  def assert_invalid_attribute(record, attribute)
    assert_not_predicate record, :valid?, "expected #{record.class.name} to be invalid"
    assert_includes record.errors.attribute_names, attribute
  end
end
