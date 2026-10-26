# frozen_string_literal: true

# The first migration of a reserved database: it gives the database a schema_migrations history so
# a migrated database and a schema-loaded one dump identically.
class CreateExtensions < ActiveRecord::Migration[8.2]
  def up
    enable_extension("pgcrypto") unless extension_enabled?("pgcrypto")
  end

  def down
    disable_extension("pgcrypto") if extension_enabled?("pgcrypto")
  end
end
