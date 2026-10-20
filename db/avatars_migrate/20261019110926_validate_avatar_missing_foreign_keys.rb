# frozen_string_literal: true

class ValidateAvatarMissingForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_foreign_key(:handle_assignments, name: "fk_handle_assignments_on_assigned_by_actor_id")
    validate_foreign_key(:avatar_persona_bindings, name: "fk_avatar_persona_bindings_on_avatar_id")
    validate_foreign_key(:avatar_individual_bindings, name: "fk_avatar_individual_bindings_on_avatar_id")
    validate_foreign_key(:avatar_agent_bindings, name: "fk_avatar_agent_bindings_on_avatar_id")
  end
end
