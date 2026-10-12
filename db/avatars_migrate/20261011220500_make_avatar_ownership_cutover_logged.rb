# frozen_string_literal: true

class MakeAvatarOwnershipCutoverLogged < ActiveRecord::Migration[8.2]
  def up
    # Rails test mode defaults newly created tables to UNLOGGED. The cutover marker is
    # authoritative deployment state and must survive a PostgreSQL restart in every environment.
    safety_assured { execute("ALTER TABLE avatar_ownership_cutovers SET LOGGED") }
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "The Avatar ownership cutover marker must remain a logged persistent table"
  end
end
