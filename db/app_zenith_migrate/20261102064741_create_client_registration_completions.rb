# frozen_string_literal: true

class CreateClientRegistrationCompletions < ActiveRecord::Migration[8.2]
  public

  def up
    create_table(:client_registration_completion_methods, id: :smallint) do |t|
      t.string(:key, limit: 16, null: false)
    end
    add_index(:client_registration_completion_methods, :key, unique: true)
    add_check_constraint(
      :client_registration_completion_methods,
      "(id = 1 AND key = 'email') OR (id = 2 AND key = 'telephone') OR " \
      "(id = 3 AND key = 'google') OR (id = 4 AND key = 'apple')",
      validate: false, name: "chk_client_registration_completion_methods",
    )
    create_table(:client_registration_completions) do |t|
      t.string(:public_id, limit: 21, null: false)
      t.bigint(:client_id, null: false)
      t.string(:sign_up_flow_ref, limit: 21, null: false)
      t.integer(:method_id, limit: 2, null: false)
      t.timestamptz(:completed_at, null: false)
    end
    add_index(:client_registration_completions, :public_id, unique: true)
    add_index(:client_registration_completions, :client_id, unique: true)
    add_index(:client_registration_completions, :sign_up_flow_ref, unique: true)
    add_foreign_key(:client_registration_completions, :clients, on_delete: :restrict, validate: false)
    add_foreign_key(
      :client_registration_completions, :client_registration_completion_methods,
      column: :method_id, on_delete: :restrict, validate: false,
    )
    add_check_constraint(
      :client_registration_completions, "char_length(public_id) = 21",
      validate: false, name: "chk_client_registration_completion_public_id",
    )
    add_check_constraint(
      :client_registration_completions, "char_length(sign_up_flow_ref) = 21",
      validate: false, name: "chk_client_registration_completion_flow_ref",
    )
    add_check_constraint(
      :client_registration_completions, "isfinite(completed_at)",
      validate: false, name: "chk_client_registration_completion_time",
    )
  end

  def down
    if connection.select_value("SELECT EXISTS (SELECT 1 FROM client_registration_completions)")
      raise ActiveRecord::IrreversibleMigration, "Registration completion history requires an approved recovery plan"
    end

    drop_table(:client_registration_completions)
    drop_table(:client_registration_completion_methods)
  end
end
