# frozen_string_literal: true

class CreateOrgAuthorityResourceLifecycles < ActiveRecord::Migration[8.2]
  def change
    create_table(:agent_lifecycles, id: :bigserial) do |t|
      t.references(
        :agent,
        null: false,
        foreign_key: { to_table: :agents, on_delete: :restrict },
        index: false,
      )
      t.string(:state, null: false)
      t.datetime(:state_changed_at, null: false, default: -> { "clock_timestamp()" })
      t.timestamps

      t.index(
        :agent_id,
        unique: true,
        name: "idx_agent_lifecycles_one_agent",
      )
    end
    add_check_constraint(
      :agent_lifecycles,
      "state IN ('active', 'inactive', 'discarded', 'deleted', 'retained')",
      name: "chk_agent_lifecycles_state",
    )

    create_table(:bureau_lifecycles, id: :bigserial) do |t|
      t.references(
        :bureau,
        null: false,
        foreign_key: { to_table: :bureaus, on_delete: :restrict },
        index: false,
      )
      t.string(:state, null: false)
      t.datetime(:state_changed_at, null: false, default: -> { "clock_timestamp()" })
      t.timestamps

      t.index(
        :bureau_id,
        unique: true,
        name: "idx_bureau_lifecycles_one_bureau",
      )
    end
    add_check_constraint(
      :bureau_lifecycles,
      "state IN ('active', 'inactive', 'discarded', 'deleted', 'retained')",
      name: "chk_bureau_lifecycles_state",
    )
  end
end
