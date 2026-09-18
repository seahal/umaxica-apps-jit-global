# typed: false
# == Schema Information
#
# Table name: operator_workspace_accounts
# Database name: org_zenith
#
#  id            :bigint           not null, primary key
#  lock_version  :integer          default(0), not null
#  moniker       :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  department_id :bigint
#  public_id     :string           not null
#  staff_id      :bigint           not null
#  status_id     :bigint           default(2), not null
#
# Indexes
#
#  index_operator_workspace_accounts_on_department_id  (department_id)
#  index_operator_workspace_accounts_on_public_id      (public_id) UNIQUE
#  index_operator_workspace_accounts_on_staff_id       (staff_id)
#  index_operator_workspace_accounts_on_status_id      (status_id)
#

# frozen_string_literal: true

class OperatorWorkspaceAccount < OrgRpRecord
  include Retainable
  include ::PublicId

  attribute :status_id, default: OperatorWorkspaceAccountStatus::NOTHING

  belongs_to :operator_workspace_account_status,
             foreign_key: :status_id,
             inverse_of: false
  belongs_to :operator,
             class_name: "Operator",
             foreign_key: :staff_id,
             inverse_of: false
  belongs_to :staff,
             class_name: "Operator",
             inverse_of: false
  belongs_to :department, inverse_of: false
  has_many :staff_operators, class_name: "OperatorWorkspaceAccountMembership", dependent: :destroy,
                             inverse_of: :operator_workspace_account
  has_many :operators,
           through: :staff_operators,
           source: :staff,
           disable_joins: true
end
