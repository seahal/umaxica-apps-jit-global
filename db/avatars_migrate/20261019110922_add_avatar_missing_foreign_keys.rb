# frozen_string_literal: true

class AddAvatarMissingForeignKeys < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key(
      :handle_assignments, :avatars, column: :assigned_by_actor_id, name: "fk_handle_assignments_on_assigned_by_actor_id",
                                     on_delete: :restrict, validate: false,
    )
    add_foreign_key(
      :avatar_persona_bindings, :avatars, column: :avatar_id, name: "fk_avatar_persona_bindings_on_avatar_id",
                                          on_delete: :restrict, validate: false,
    )
    add_foreign_key(
      :avatar_individual_bindings, :avatars, column: :avatar_id, name: "fk_avatar_individual_bindings_on_avatar_id",
                                             on_delete: :restrict, validate: false,
    )
    add_foreign_key(
      :avatar_agent_bindings, :avatars, column: :avatar_id, name: "fk_avatar_agent_bindings_on_avatar_id",
                                        on_delete: :restrict, validate: false,
    )
  end
end
