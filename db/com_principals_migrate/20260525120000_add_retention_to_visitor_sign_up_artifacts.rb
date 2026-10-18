# frozen_string_literal: true
class AddRetentionToVisitorSignUpArtifacts < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLES = %i[
    visitor_emails
    visitor_telephones
    visitor_passkeys
  ].freeze

  def change
    TABLES.each do |table_name|
      safety_assured do
        add_column table_name, :discarded_at, :datetime, null: false, default: -> { "'infinity'" } unless
          column_exists?(table_name, :discarded_at)
        add_column table_name, :purged_at, :datetime, null: false, default: -> { "'infinity'" } unless
          column_exists?(table_name, :purged_at)
      end

      add_index table_name, :discarded_at, algorithm: :concurrently, if_not_exists: true
      add_index table_name, :purged_at, algorithm: :concurrently, if_not_exists: true
      add_check_constraint(
        table_name,
        "discarded_at <= purged_at",
        name: "chk_#{table_name}_retention_order",
        validate: false,
        if_not_exists: true,
      )
    end
  end
end
