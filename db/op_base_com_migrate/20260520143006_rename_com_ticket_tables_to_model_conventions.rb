# frozen_string_literal: true

class RenameComTicketTablesToModelConventions < ActiveRecord::Migration[8.2]
  def up
    rename_table_strict :com_sign_in_cycles, :visitor_sign_in_cycles
    rename_table_strict :com_sign_up_cycles, :visitor_sign_up_cycles
  end

  def down
    rename_table_strict :visitor_sign_up_cycles, :com_sign_up_cycles
    rename_table_strict :visitor_sign_in_cycles, :com_sign_in_cycles
  end
end
