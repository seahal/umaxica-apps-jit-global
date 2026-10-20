# frozen_string_literal: true

class CascadeOpBaseComDependentDeletes < ActiveRecord::Migration[8.2]
  # [table, referenced table, column, constraint, replaced constraint]; the parent model already declares
  # dependent: :delete_all, so the database deletes the same children instead of blocking the parent.
  FOREIGN_KEYS = [
    [:visitor_verifications, :visitor_tokens, :visitor_token_id, "fk_visitor_verifications_on_visitor_token_id", "fk_rails_2b1e12b132"],
  ].freeze

  def change
    FOREIGN_KEYS.each do |table, to_table, column, name, replaced|
      add_foreign_key(table, to_table, column:, name:, on_delete: :cascade, validate: false)
      remove_foreign_key(table, to_table, column:, name: replaced)
    end
  end
end
