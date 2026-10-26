# frozen_string_literal: true

# D-179 (2): op_org_authority_stops is the sole durable sign-out authority.
# The owner authorized these tables to be dropped as part of the database rebuild (D-159, D-168).
class DropSignOutFlowsOpBaseOrg < ActiveRecord::Migration[8.2]
  def up
    drop_table(:operator_sign_out_flows)
    drop_table(:operator_sign_out_flow_kinds)
    drop_table(:operator_sign_out_flow_statuses)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "operator sign-out flow records were retired by D-179 (2)"
  end
end
