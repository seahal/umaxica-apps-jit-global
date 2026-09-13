# frozen_string_literal: true

# Durable Apple/Google bindings are read on authenticated GET pages such as
# /identity. PostgreSQL refuses UNLOGGED relations on a hot standby
# (`cannot access temporary or unlogged relations during recovery`), and
# AppPrincipalRecord reads from app_zenith_replica.
class LogClientExternalIdentities < ActiveRecord::Migration[8.2]
  def up
    safety_assured { execute("ALTER TABLE client_external_identities SET LOGGED") }
  end

  def down
    safety_assured { execute("ALTER TABLE client_external_identities SET UNLOGGED") }
  end
end
