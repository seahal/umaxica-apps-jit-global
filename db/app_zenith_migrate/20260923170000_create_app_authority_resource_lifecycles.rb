# frozen_string_literal: true

class CreateAppAuthorityResourceLifecycles < ActiveRecord::Migration[8.2]
  def change
    create_table(:client_persona_lifecycles, id: :bigserial) do |t|
      t.references(
        :client_persona,
        null: false,
        foreign_key: { to_table: :personas, on_delete: :restrict },
        index: false,
      )
      t.string(:state, null: false)
      t.datetime(:state_changed_at, null: false, default: -> { "clock_timestamp()" })
      t.timestamps

      t.index(
        :client_persona_id,
        unique: true,
        name: "idx_client_persona_lifecycles_one_client_persona",
      )
    end
    add_check_constraint(
      :client_persona_lifecycles,
      "state IN ('active', 'inactive', 'discarded', 'deleted', 'retained')",
      name: "chk_client_persona_lifecycles_state",
    )

    create_table(:enterprise_lifecycles, id: :bigserial) do |t|
      t.references(
        :enterprise,
        null: false,
        foreign_key: { to_table: :enterprises, on_delete: :restrict },
        index: false,
      )
      t.string(:state, null: false)
      t.datetime(:state_changed_at, null: false, default: -> { "clock_timestamp()" })
      t.timestamps

      t.index(
        :enterprise_id,
        unique: true,
        name: "idx_enterprise_lifecycles_one_enterprise",
      )
    end
    add_check_constraint(
      :enterprise_lifecycles,
      "state IN ('active', 'inactive', 'discarded', 'deleted', 'retained')",
      name: "chk_enterprise_lifecycles_state",
    )
  end
end
