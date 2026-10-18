# typed: false
# frozen_string_literal: true

ActiveSupport.on_load(:active_record) do
  module SchemaMigrationIfNotExists
    public

    def create_table
      @pool.with_connection do |connection|
        connection.create_table(table_name, id: false, if_not_exists: true) do |t|
          t.string(:version, **connection.internal_string_options_for_primary_key)
        end
      end
    end
  end

  ActiveRecord::SchemaMigration.prepend(SchemaMigrationIfNotExists)
end
