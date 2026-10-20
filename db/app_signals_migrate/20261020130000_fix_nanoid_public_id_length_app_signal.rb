# frozen_string_literal: true

class FixNanoidPublicIdLengthAppSignal < ActiveRecord::Migration[8.2]
  # adr/identifier-contract.md: NanoID public_id is varchar(21) with an exact-length CHECK.
  # [table, previous varchar limit (nil = unbounded), replaced capacity check name, its expression]
  TABLES = [
    [:client_notification_records, nil, "client_notification_records_public_id_max_length", "char_length(public_id::text) <= 25"],
    [:member_notifications, nil, "member_notifications_public_id_max_length", "char_length(public_id::text) <= 25"],
  ].freeze

  def up
    TABLES.each do |table, previous_limit, capacity_check, _expression|
      remove_check_constraint(table, name: capacity_check) if capacity_check
      # Narrowing the type is reviewed here: every stored value is a 21-character NanoID.
      safety_assured { change_column(table, :public_id, :string, limit: 21) } unless previous_limit == 21
      add_check_constraint(table, "char_length(public_id) = 21", name: "chk_#{table}_pid", validate: false)
    end
  end

  def down
    TABLES.reverse_each do |table, previous_limit, capacity_check, expression|
      remove_check_constraint(table, name: "chk_#{table}_pid")
      safety_assured { change_column(table, :public_id, :string, limit: previous_limit) } unless previous_limit == 21
      add_check_constraint(table, expression, name: capacity_check) if capacity_check
    end
  end
end
