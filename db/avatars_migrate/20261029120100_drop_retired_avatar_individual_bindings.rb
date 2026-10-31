# frozen_string_literal: true

# WU-5: Individuals and AvatarIndividualBinding belonged to the retired com realm visitor account
# family. Avatar provisioning only creates persona and agent bindings now.
class DropRetiredAvatarIndividualBindings < ActiveRecord::Migration[8.2]
  def up
    safety_assured { drop_table :avatar_individual_bindings }
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "retired avatar individual bindings were intentionally removed"
  end
end
