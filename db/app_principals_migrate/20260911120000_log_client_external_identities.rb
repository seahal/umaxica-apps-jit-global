# frozen_string_literal: true

# Durable Apple/Google bindings are read on authenticated GET pages such as
# /identity. PostgreSQL refuses UNLOGGED relations on a hot standby
# (`cannot access temporary or unlogged relations during recovery`), and
# AppPrincipalRecord reads from app_zenith_replica.
class LogClientExternalIdentities < ActiveRecord::Migration[8.2]
  def up
    # Test sets create_unlogged_tables=true, so clients and their neighbors are
    # already UNLOGGED. SET LOGGED on one child fails while any FK neighbor stays
    # UNLOGGED. Skip in that mode; production/dev tables are logged by default
    # except this explicit durability flip.
    return if connection.create_unlogged_tables

    safety_assured { execute("ALTER TABLE client_external_identities SET LOGGED") }
  end

  def down
    return if connection.create_unlogged_tables

    safety_assured { execute("ALTER TABLE client_external_identities SET UNLOGGED") }
  end
end
