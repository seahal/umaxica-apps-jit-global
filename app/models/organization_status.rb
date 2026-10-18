# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: organization_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
class OrganizationStatus < OrgPrincipalRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 1
  DEFAULTS = [NOTHING].freeze
  has_many :organizations,
           class_name: "OperatorOrganization",
           foreign_key: :workspace_status_id,
           dependent: :restrict_with_error,
           inverse_of: :organization_status
  has_many :departments,
           class_name: "Department",
           dependent: :restrict_with_error,
           inverse_of: :department_status
end
