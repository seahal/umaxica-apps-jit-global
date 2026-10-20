# frozen_string_literal: true

class RemoveCoveredAvatarIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    remove_index(:avatar_persona_bindings, %i(avatar_id persona_id), name: "idx_avatar_persona_bindings_active_pair", unique: true, where: "(revoked_at IS NULL)", algorithm: :concurrently)
    remove_index(:avatar_lifecycle_events, :avatar_id, name: "index_avatar_lifecycle_events_on_avatar_id", algorithm: :concurrently)
    remove_index(:avatar_individual_bindings, %i(avatar_id individual_id), name: "idx_avatar_individual_bindings_active_pair", unique: true, where: "(revoked_at IS NULL)", algorithm: :concurrently)
    remove_index(:avatar_agent_bindings, %i(avatar_id agent_id), name: "idx_avatar_agent_bindings_active_pair", unique: true, where: "(revoked_at IS NULL)", algorithm: :concurrently)
    remove_index(:avatar_mutes, :muter_avatar_id, name: "index_avatar_mutes_on_muter_avatar_id", algorithm: :concurrently)
    remove_index(:avatar_blocks, :blocker_avatar_id, name: "index_avatar_blocks_on_blocker_avatar_id", algorithm: :concurrently)
    remove_index(:avatar_follows, :follower_avatar_id, name: "index_avatar_follows_on_follower_avatar_id", algorithm: :concurrently)
  end
end
