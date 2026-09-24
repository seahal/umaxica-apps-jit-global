# frozen_string_literal: true

class CreateAppAuthorityCutovers < ActiveRecord::Migration[8.2]
  def change
    create_table(:client_persona_authority_cutovers, id: :bigint) do |t|
      t.datetime(:cutover_at, null: false, default: -> { "clock_timestamp()" })
      t.timestamps
    end
    add_check_constraint(
      :client_persona_authority_cutovers,
      "id = 1",
      name: "chk_client_persona_authority_cutovers_singleton",
    )
    add_check_constraint(
      :client_persona_authority_cutovers,
      "isfinite(cutover_at)",
      name: "chk_client_persona_authority_cutovers_finite_time",
    )

    create_table(:enterprise_authority_cutovers, id: :bigint) do |t|
      t.datetime(:cutover_at, null: false, default: -> { "clock_timestamp()" })
      t.timestamps
    end
    add_check_constraint(
      :enterprise_authority_cutovers,
      "id = 1",
      name: "chk_enterprise_authority_cutovers_singleton",
    )
    add_check_constraint(
      :enterprise_authority_cutovers,
      "isfinite(cutover_at)",
      name: "chk_enterprise_authority_cutovers_finite_time",
    )
  end
end
