# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: departments
# Database name: org_principal
#
#  id                   :bigint           not null, primary key
#  name                 :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  department_status_id :bigint           default(0), not null
#  parent_id            :bigint
#  workspace_id         :bigint
#
# Indexes
#
#  index_departments_on_department_status_id_and_parent_id  (department_status_id,parent_id) UNIQUE
#  index_departments_on_parent_id                           (parent_id)
#  index_departments_on_workspace_id                        (workspace_id)
#
# Foreign Keys
#
#  fk_departments_on_department_status_id  (department_status_id => department_statuses.id)
#  fk_rails_...                            (parent_id => departments.id)
#  fk_rails_...                            (workspace_id => organizations.id) ON DELETE => nullify
#

class Department < OrgPrincipalRecord
  self.belongs_to_required_by_default = false

  belongs_to :parent,
             class_name: "Department",
             inverse_of: :children
  has_many :children,
           class_name: "Department",
           foreign_key: :parent_id,
           inverse_of: :parent,
           dependent: :restrict_with_error

  belongs_to :department_status,
             class_name: "DepartmentStatus",
             primary_key: :id,
             inverse_of: :departments

  belongs_to :workspace, class_name: "OperatorOrganization", inverse_of: :departments
  has_many :operator_workspace_accounts,
           class_name: "OperatorWorkspaceAccount",
           dependent: :nullify,
           inverse_of: false
  has_many :operators,
           class_name: "OperatorWorkspaceAccount",
           dependent: :nullify,
           inverse_of: false

  validates :name, presence: true
  validates :department_status_id,
            length: { maximum: 255 },
            uniqueness: { scope: :parent_id,
                          message: :already_tagged, }
end
