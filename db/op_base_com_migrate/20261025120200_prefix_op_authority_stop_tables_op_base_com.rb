# frozen_string_literal: true

# WU-16: the authority-stop tables carry the realm prefix like every other per-realm OP table
# (`op_com_grants`), so model, table and fixture names agree across the three OP databases.
class PrefixOpAuthorityStopTablesOpBaseCom < ActiveRecord::Migration[8.2]
  # The tables were created in the preceding migration of this change and are not yet read by any
  # deployed process (D-159 reset), so the rename cannot break a running reader.
  def change
    safety_assured do
      rename_table(:op_authority_stop_causes, :op_com_authority_stop_causes)
      rename_table(:op_authority_stop_scopes, :op_com_authority_stop_scopes)
      rename_table(:op_authority_stop_participant_statuses, :op_com_authority_stop_participant_statuses)
      rename_table(:op_authority_stops, :op_com_authority_stops)
      rename_table(:op_authority_stop_root_targets, :op_com_authority_stop_root_targets)
      rename_table(:op_authority_stop_grant_targets, :op_com_authority_stop_grant_targets)
      rename_table(:op_authority_stop_epoch_cutoffs, :op_com_authority_stop_epoch_cutoffs)
      rename_table(:op_authority_stop_participants, :op_com_authority_stop_participants)
      rename_table(:op_authority_stop_browser_logouts, :op_com_authority_stop_browser_logouts)
    end
  end
end
