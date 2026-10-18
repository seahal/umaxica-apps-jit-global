# frozen_string_literal: true
class RenameOrgSignSequenceTicketsToCycles < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      rename_table_strict :org_sign_in_sequence_tickets, :org_sign_in_cycles
      rename_table_strict :org_sign_up_sequence_tickets, :org_sign_up_cycles
    end
  end

  def down
    safety_assured do
      rename_table_strict :org_sign_in_cycles, :org_sign_in_sequence_tickets
      rename_table_strict :org_sign_up_cycles, :org_sign_up_sequence_tickets
    end
  end
end
