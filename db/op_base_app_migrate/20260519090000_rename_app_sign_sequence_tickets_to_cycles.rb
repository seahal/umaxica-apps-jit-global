# frozen_string_literal: true
class RenameAppSignSequenceTicketsToCycles < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      rename_table_strict :app_sign_in_sequence_tickets, :app_sign_in_cycles
      rename_table_strict :app_sign_up_sequence_tickets, :app_sign_up_cycles
    end
  end

  def down
    safety_assured do
      rename_table_strict :app_sign_in_cycles, :app_sign_in_sequence_tickets
      rename_table_strict :app_sign_up_cycles, :app_sign_up_sequence_tickets
    end
  end
end
