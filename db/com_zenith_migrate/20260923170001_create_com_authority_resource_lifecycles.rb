# frozen_string_literal: true

class CreateComAuthorityResourceLifecycles < ActiveRecord::Migration[8.2]
  def change
    create_table(:individual_lifecycles, id: :bigserial) do |t|
      t.references(
        :individual,
        null: false,
        foreign_key: { to_table: :individuals, on_delete: :restrict },
        index: false,
      )
      t.string(:state, null: false)
      t.datetime(:state_changed_at, null: false, default: -> { "clock_timestamp()" })
      t.timestamps

      t.index(
        :individual_id,
        unique: true,
        name: "idx_individual_lifecycles_one_individual",
      )
    end
    add_check_constraint(
      :individual_lifecycles,
      "state IN ('active', 'inactive', 'discarded', 'deleted', 'retained')",
      name: "chk_individual_lifecycles_state",
    )

    create_table(:company_lifecycles, id: :bigserial) do |t|
      t.references(
        :company,
        null: false,
        foreign_key: { to_table: :companies, on_delete: :restrict },
        index: false,
      )
      t.string(:state, null: false)
      t.datetime(:state_changed_at, null: false, default: -> { "clock_timestamp()" })
      t.timestamps

      t.index(
        :company_id,
        unique: true,
        name: "idx_company_lifecycles_one_company",
      )
    end
    add_check_constraint(
      :company_lifecycles,
      "state IN ('active', 'inactive', 'discarded', 'deleted', 'retained')",
      name: "chk_company_lifecycles_state",
    )
  end
end
