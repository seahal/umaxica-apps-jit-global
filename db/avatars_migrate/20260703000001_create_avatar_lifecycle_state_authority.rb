# frozen_string_literal: true

class CreateAvatarLifecycleStateAuthority < ActiveRecord::Migration[8.2]
  class MigrationAvatarLifecycleState < ActiveRecord::Base
    self.table_name = "avatar_lifecycle_states"
  end

  class MigrationAvatar < ActiveRecord::Base
    self.table_name = "avatars"
  end

  STATE_ROWS = [
    {
      key: "active",
      title: "Active",
      description: "Avatar can create content and participate in normal public surfaces.",
      can_create_content: true,
      visible_by_default: true,
      editable_by_owner: true,
      restorable_by_owner: false,
      followable: true,
      group_attachable: true,
      discoverable: true,
      moderation_visible: true,
      terminal: false,
      sort_order: 10,
    },
    {
      key: "suspended",
      title: "Suspended",
      description: "Avatar cannot create content and is excluded from follow, group, and discovery surfaces until moderator or admin restoration.",
      can_create_content: false,
      visible_by_default: false,
      editable_by_owner: true,
      restorable_by_owner: false,
      followable: false,
      group_attachable: false,
      discoverable: false,
      moderation_visible: true,
      terminal: false,
      sort_order: 20,
    },
    {
      key: "archived",
      title: "Archived",
      description: "Avatar is owner-retirable, cannot create content, and is excluded from public discovery, follow, and group attach.",
      can_create_content: false,
      visible_by_default: false,
      editable_by_owner: true,
      restorable_by_owner: true,
      followable: false,
      group_attachable: false,
      discoverable: false,
      moderation_visible: true,
      terminal: false,
      sort_order: 30,
    },
    {
      key: "banned",
      title: "Banned",
      description: "Avatar cannot create content or be restored by the owner; only moderator or admin authority may transition it.",
      can_create_content: false,
      visible_by_default: false,
      editable_by_owner: false,
      restorable_by_owner: false,
      followable: false,
      group_attachable: false,
      discoverable: false,
      moderation_visible: true,
      terminal: false,
      sort_order: 40,
    },
    {
      key: "deleted",
      title: "Deleted",
      description: "Terminal state retained only for audit, legal, or minimum authority records.",
      can_create_content: false,
      visible_by_default: false,
      editable_by_owner: false,
      restorable_by_owner: false,
      followable: false,
      group_attachable: false,
      discoverable: false,
      moderation_visible: true,
      terminal: true,
      sort_order: 50,
    },
  ].freeze

  def up
    create_table(:avatar_lifecycle_states) do |t|
      t.string(:key, null: false)
      t.string(:title, null: false)
      t.text(:description)
      t.boolean(:can_create_content, null: false)
      t.boolean(:visible_by_default, null: false)
      t.boolean(:editable_by_owner, null: false)
      t.boolean(:restorable_by_owner, null: false)
      t.boolean(:followable, null: false)
      t.boolean(:group_attachable, null: false)
      t.boolean(:discoverable, null: false)
      t.boolean(:moderation_visible, null: false)
      t.boolean(:terminal, null: false)
      t.integer(:sort_order, null: false)
      t.timestamps
    end

    add_index(:avatar_lifecycle_states, :key, unique: true)
    add_index(:avatar_lifecycle_states, :sort_order, unique: true)

    create_table(:avatar_lifecycle_events) do |t|
      t.references(:avatar, null: false, foreign_key: true)
      t.string(:from_state_key, null: false)
      t.string(:to_state_key, null: false)
      t.string(:changed_by_type)
      t.string(:changed_by_public_id)
      t.text(:reason)
      t.jsonb(:metadata, null: false, default: {})
      t.datetime(:created_at, null: false)

      t.index(:created_at)
      t.index([:avatar_id, :created_at])
      t.index(:changed_by_public_id)
    end

    safety_assured do
      add_reference(:avatars, :lifecycle_state, foreign_key: { to_table: :avatar_lifecycle_states })
    end

    seed_into(connection)

    MigrationAvatarLifecycleState.reset_column_information
    active_state = MigrationAvatarLifecycleState.find_by!(key: "active")
    MigrationAvatar.reset_column_information
    MigrationAvatar.find_each do |avatar|
      avatar.update_columns(lifecycle_state_id: active_state.id)
    end

    safety_assured do
      change_column_null(:avatars, :lifecycle_state_id, false)
    end
  end

  # Structure loads mark migrations as applied without replaying their data
  # inserts. db/seeds.rb calls this same idempotent writer on the avatar
  # connection so a reset database still has the lifecycle states that avatar
  # provisioning requires.
  def seed_into(target_connection)
    unless target_connection.data_source_exists?("avatar_lifecycle_states")
      raise ActiveRecord::MigrationError,
            "avatar_lifecycle_states must exist before lifecycle reference data is inserted"
    end

    now = target_connection.quote(Time.current)
    columns = STATE_ROWS.first.keys
    values =
      STATE_ROWS.map do |row|
        "(#{columns.map { |column| target_connection.quote(row.fetch(column)) }.join(", ")}, #{now}, #{now})"
      end

    target_connection.execute(<<~SQL.squish)
      INSERT INTO avatar_lifecycle_states (#{columns.join(", ")}, created_at, updated_at)
      VALUES #{values.join(", ")}
      ON CONFLICT (key) DO NOTHING
    SQL
  end

  def down
    remove_reference(:avatars, :lifecycle_state, foreign_key: { to_table: :avatar_lifecycle_states })
    drop_table(:avatar_lifecycle_events)
    drop_table(:avatar_lifecycle_states)
  end
end
