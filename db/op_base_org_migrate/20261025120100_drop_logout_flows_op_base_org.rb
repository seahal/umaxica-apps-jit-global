# frozen_string_literal: true

# WU-16 (two.md 5.8 v2, D-158 P-142): the authority-stop tables replace the browser-bound logout
# Flow, its Participants, Receipts and the OP outbox. Replaced, not migrated (D-159, D-168): the
# owner resets the databases, so there are no rows to carry over and no way back to them.
class DropLogoutFlowsOpBaseOrg < ActiveRecord::Migration[8.2]
  def up
    drop_table(:op_outbox_events)
    drop_table(:logout_receipts)
    drop_table(:logout_flow_participants)
    drop_table(:logout_flows)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "logout_flows were replaced by op_authority_stops (D-168)"
  end
end
