# frozen_string_literal: true

class AddOperatorTokenDeviceSessionActorForeignKey < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("SET LOCAL lock_timeout = '5s'")
      execute("SET LOCAL statement_timeout = '30min'")

      add_foreign_key(
        :operator_tokens, :operator_device_sessions,
        column: %i(staff_id device_session_id),
        primary_key: %i(staff_id id),
        name: "fk_operator_tokens_on_staff_id_and_device_session_id",
        on_delete: :restrict,
        validate: false,
      )
    end
  end

  def down
    safety_assured do
      remove_foreign_key(:operator_tokens, name: "fk_operator_tokens_on_staff_id_and_device_session_id")
    end
  end
end
