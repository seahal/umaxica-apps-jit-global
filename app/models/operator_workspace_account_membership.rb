# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: operator_workspace_account_memberships
# Database name: org_zenith
#
#  id                            :bigint           not null, primary key
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  operator_workspace_account_id :bigint           not null
#  staff_id                      :bigint           not null
#
# Indexes
#
#  idx_operator_workspace_memberships_on_account_id         (operator_workspace_account_id)
#  idx_operator_workspace_memberships_on_staff_and_account  (staff_id,operator_workspace_account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (operator_workspace_account_id => operator_workspace_accounts.id) ON DELETE => cascade
#

class OperatorWorkspaceAccountMembership < OrgRpRecord
  belongs_to :staff,
             class_name: "Operator",
             inverse_of: false
  belongs_to :operator_workspace_account,
             class_name: "OperatorWorkspaceAccount",
             inverse_of: :staff_operators

  validates :operator_workspace_account_id, uniqueness: { scope: :staff_id }
end
