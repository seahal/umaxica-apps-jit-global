# frozen_string_literal: true

class AddComZenithMissingForeignKeys < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key(
      :visitor_accounts, :visitors, column: :visitor_id, name: "fk_visitor_accounts_on_visitor_id",
                                    on_delete: :restrict, validate: false,
    )
    add_foreign_key(
      :core_com_visitor_bridges, :visitors, column: :visitor_id, name: "fk_core_com_visitor_bridges_on_visitor_id",
                                            on_delete: :restrict, validate: false,
    )
  end
end
