# frozen_string_literal: true

class AddStatusToOperatorAuthAdmissionBindings < ActiveRecord::Migration[8.2]
  ISSUED = 10
  ATTACHED = 20
  BASE_CONFIRMED = 30
  REDEEMED = 40
  RETIRED = 90
  SWITCHED = 91
  STATUS_IDS = [ISSUED, ATTACHED, BASE_CONFIRMED, REDEEMED, RETIRED, SWITCHED].freeze

  def change
    create_table(:operator_auth_admission_binding_statuses, id: :bigint)
    add_column(:operator_auth_admission_bindings, :status_id, :bigint, default: ISSUED, null: false)

    reversible do |direction|
      direction.up do
        set_status_reference_logged
        seed_status_rows
        backfill_status_ids
      end
    end

    reversible do |direction|
      direction.up { add_status_foreign_key }
      direction.down do
        remove_foreign_key(:operator_auth_admission_bindings, column: :status_id)
      end
    end

    add_check_constraint(
      :operator_auth_admission_bindings,
      "(status_id = #{ISSUED} AND auth_ceremony_session_id IS NULL AND confirmation_ref IS NULL AND " \
      "base_confirmed_at IS NULL AND redeemed_at IS NULL AND admitted_auth_ceremony_session_id IS NULL AND retired_at IS NULL) OR " \
      "(status_id = #{ATTACHED} AND auth_ceremony_session_id IS NOT NULL AND confirmation_ref IS NOT NULL AND " \
      "base_confirmed_at IS NULL AND redeemed_at IS NULL AND admitted_auth_ceremony_session_id IS NULL AND retired_at IS NULL) OR " \
      "(status_id = #{BASE_CONFIRMED} AND auth_ceremony_session_id IS NOT NULL AND confirmation_ref IS NOT NULL AND " \
      "base_confirmed_at IS NOT NULL AND redeemed_at IS NULL AND admitted_auth_ceremony_session_id IS NULL AND retired_at IS NULL) OR " \
      "(status_id = #{REDEEMED} AND auth_ceremony_session_id IS NOT NULL AND confirmation_ref IS NOT NULL AND " \
      "base_confirmed_at IS NOT NULL AND redeemed_at IS NOT NULL AND " \
      "admitted_auth_ceremony_session_id IS NOT NULL AND retired_at IS NULL) OR " \
      "(status_id = #{RETIRED} AND redeemed_at IS NULL AND admitted_auth_ceremony_session_id IS NULL AND retired_at IS NOT NULL) OR " \
      "(status_id = #{SWITCHED} AND auth_ceremony_session_id IS NOT NULL AND confirmation_ref IS NOT NULL AND " \
      "base_confirmed_at IS NOT NULL AND redeemed_at IS NOT NULL AND " \
      "admitted_auth_ceremony_session_id IS NOT NULL AND retired_at IS NULL)",
      name: "operator_admission_binding_status_facts",
      validate: false,
    )
  end

  private

  def set_status_reference_logged
    safety_assured do
      execute("ALTER TABLE public.operator_auth_admission_binding_statuses SET LOGGED")
    end
  end

  def seed_status_rows
    values = STATUS_IDS.map { |id| "(#{id})" }.join(", ")
    safety_assured do
      execute("INSERT INTO operator_auth_admission_binding_statuses (id) VALUES #{values}")
    end
  end

  def add_status_foreign_key
    safety_assured do
      execute(<<~SQL.squish)
        ALTER TABLE public.operator_auth_admission_bindings
        ADD CONSTRAINT fk_operator_admission_bindings_status
        FOREIGN KEY (status_id)
        REFERENCES public.operator_auth_admission_binding_statuses (id)
        ON DELETE RESTRICT NOT VALID
      SQL
    end
  end

  def backfill_status_ids
    safety_assured do
      execute(<<~SQL.squish)
        UPDATE operator_auth_admission_bindings
        SET status_id = CASE
          WHEN retired_at IS NOT NULL THEN #{RETIRED}
          WHEN redeemed_at IS NOT NULL THEN #{REDEEMED}
          WHEN base_confirmed_at IS NOT NULL THEN #{BASE_CONFIRMED}
          WHEN auth_ceremony_session_id IS NOT NULL THEN #{ATTACHED}
          ELSE #{ISSUED}
        END
      SQL
    end
  end
end
