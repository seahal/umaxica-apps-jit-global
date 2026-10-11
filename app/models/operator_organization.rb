# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: organizations
# Database name: org_zenith
#
# Legacy operator organization hierarchy. The physical table and operational
# behavior remain unchanged; the concrete Ruby name no longer occupies the
# shared Organization interface constant.
class OperatorOrganization < OrgPrincipalRecord
  self.table_name = "organizations"

  include ::Organization

  organization_interface_validations

  belongs_to :organization_status,
             class_name: "OrganizationStatus",
             foreign_key: :workspace_status_id,
             primary_key: :id,
             inverse_of: :organizations

  has_many :divisions,
           dependent: :restrict_with_error,
           inverse_of: :organization
  has_many :departments, dependent: :nullify, inverse_of: :workspace

  validates :domain, presence: true, uniqueness: true
  validates :name, presence: true
  validates :workspace_status_id, numericality: { only_integer: true }, allow_nil: true
end
