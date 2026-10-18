# frozen_string_literal: true

class RenameCustomerActorToVisitor < ActiveRecord::Migration[8.2]
  TABLE_RENAMES = {
    customer_reauth_sessions: :visitor_reauth_sessions,
    customer_token_binding_methods: :visitor_token_binding_methods,
    customer_token_dbsc_statuses: :visitor_token_dbsc_statuses,
    customer_token_kinds: :visitor_token_kinds,
    customer_token_statuses: :visitor_token_statuses,
    customer_tokens: :visitor_tokens,
    customer_verifications: :visitor_verifications,
  }.freeze

  COLUMN_RENAMES = {
    visitor_reauth_sessions: {
      customer_token_id: :visitor_token_id,
    },
    visitor_tokens: {
      customer_id: :visitor_id,
      customer_token_binding_method_id: :visitor_token_binding_method_id,
      customer_token_dbsc_status_id: :visitor_token_dbsc_status_id,
      customer_token_kind_id: :visitor_token_kind_id,
      customer_token_status_id: :visitor_token_status_id,
    },
    visitor_verifications: {
      customer_token_id: :visitor_token_id,
    },
  }.freeze

  def up
    safety_assured do
      rename_tables(TABLE_RENAMES)
      rename_columns(COLUMN_RENAMES)
      rename_database_objects("customer", "visitor")
    end
  end

  def down
    safety_assured do
      rename_columns(COLUMN_RENAMES.transform_values(&:invert))
      rename_tables(TABLE_RENAMES.invert)
      rename_database_objects("visitor", "customer")
    end
  end

  private

  def rename_tables(renames)
    renames.each do |old_name, new_name|
      rename_table(old_name, new_name) if table_exists?(old_name) && !table_exists?(new_name)
    end
  end

  def rename_columns(renames)
    renames.each do |table_name, columns|
      next unless table_exists?(table_name)

      columns.each do |old_name, new_name|
        rename_column(table_name, old_name, new_name) if column_exists?(table_name, old_name)
      end
    end
  end

  def rename_database_objects(old_fragment, new_fragment)
    connection.tables.each do |table_name|
      indexes(table_name).each do |index|
        next unless index.name.include?(old_fragment)

        new_name = index.name.gsub(old_fragment, new_fragment)
        rename_index(table_name, index.name, new_name) unless index_name_exists?(table_name, new_name)
      end

      next unless respond_to?(:rename_check_constraint)

      check_constraints(table_name).each do |constraint|
        next unless constraint.name.include?(old_fragment)

        new_name = constraint.name.gsub(old_fragment, new_fragment)
        rename_check_constraint(table_name, constraint.name, new_name)
      end
    end
  end
end
