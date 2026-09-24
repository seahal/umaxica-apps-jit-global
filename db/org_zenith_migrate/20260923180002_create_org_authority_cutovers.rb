# frozen_string_literal: true

class CreateOrgAuthorityCutovers < ActiveRecord::Migration[8.2]
  def change
    create_table(:agent_authority_cutovers, id: :bigint) do |t|
      t.datetime(:cutover_at, null: false, default: -> { "clock_timestamp()" })
      t.timestamps
    end
    add_check_constraint(
      :agent_authority_cutovers,
      "id = 1",
      name: "chk_agent_authority_cutovers_singleton",
    )
    add_check_constraint(
      :agent_authority_cutovers,
      "isfinite(cutover_at)",
      name: "chk_agent_authority_cutovers_finite_time",
    )

    create_table(:bureau_authority_cutovers, id: :bigint) do |t|
      t.datetime(:cutover_at, null: false, default: -> { "clock_timestamp()" })
      t.timestamps
    end
    add_check_constraint(
      :bureau_authority_cutovers,
      "id = 1",
      name: "chk_bureau_authority_cutovers_singleton",
    )
    add_check_constraint(
      :bureau_authority_cutovers,
      "isfinite(cutover_at)",
      name: "chk_bureau_authority_cutovers_finite_time",
    )
  end
end
