# frozen_string_literal: true

class CreateAvatarAccessGrants < ActiveRecord::Migration[8.2]
  TABLES = {
    avatar_enterprise_persona_grants: {
      period_table: :avatar_enterprise_ownership_periods,
      period_column: :avatar_enterprise_ownership_period_id,
      subject_column: :persona_public_id,
      code: "enterprise_persona",
    },
    avatar_bureau_agent_grants: {
      period_table: :avatar_bureau_ownership_periods,
      period_column: :avatar_bureau_ownership_period_id,
      subject_column: :agent_public_id,
      code: "bureau_agent",
    },
  }.freeze

  CAPABILITIES = %w(
    avatar.view
    avatar.update
    avatar.group.manage
    avatar.group.attach
    avatar.group.detach
  ).freeze

  def up
    TABLES.each do |table, definition|
      create_grant_table(table, definition)
      add_grant_constraints(table, definition)
    end
  end

  def down
    TABLES.each_key { |table| drop_table(table) }
  end

  private

  def create_grant_table(table, definition)
    create_table(table) do |t|
      t.references(
        definition.fetch(:period_column).to_s.delete_suffix("_id").to_sym, null: false, index: false,
                                                                           foreign_key: { to_table: definition.fetch(:period_table), on_delete: :restrict },
      )
      t.string(:public_id, null: false, limit: 21)
      t.string(definition.fetch(:subject_column), null: false, limit: 25)
      t.string(:capability, null: false, limit: 50)
      t.string(:granted_by_actor_public_id, null: false, limit: 25)
      t.datetime(:granted_at, null: false)
      t.datetime(:revoked_at)
      t.timestamps
    end

    add_index(table, :public_id, unique: true, name: "idx_#{table}_public_id")
    add_index(table, definition.fetch(:period_column), name: "idx_#{table}_period")
    add_index(
      table,
      [definition.fetch(:period_column), definition.fetch(:subject_column), :capability],
      unique: true,
      where: "revoked_at IS NULL",
      name: "idx_#{table}_active_subject_capability",
    )
  end

  def add_grant_constraints(table, definition)
    subject_column = definition.fetch(:subject_column)
    add_check_constraint(
      table,
      "char_length(btrim(#{subject_column})) > 0 AND " \
      "char_length(btrim(public_id)) > 0 AND " \
      "char_length(btrim(capability)) > 0 AND " \
      "char_length(btrim(granted_by_actor_public_id)) > 0",
      name: "chk_#{table}_nonblank",
    )
    add_check_constraint(
      table,
      "capability IN (#{CAPABILITIES.map { |capability| connection.quote(capability) }.join(", ")})",
      name: "chk_#{table}_capability",
    )
    add_check_constraint(
      table,
      "revoked_at IS NULL OR revoked_at >= granted_at",
      name: "chk_#{table}_revocation_order",
    )
  end
end
