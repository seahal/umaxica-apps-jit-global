# frozen_string_literal: true

class AddOperatorDeviceSessionTokenForeignKeys < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("SET LOCAL lock_timeout = '5s'")
      execute("SET LOCAL statement_timeout = '30min'")

      add_foreign_key(
        :operator_tokens,
        :operator_device_sessions,
        column: :device_session_id,
        name: "fk_operator_tokens_on_device_session_id",
        on_delete: :restrict,
        validate: false,
      )

      execute(<<~SQL.squish)
        ALTER TABLE operator_device_sessions
        ADD CONSTRAINT fk_operator_device_sessions_on_current_refresh_token_owner
        FOREIGN KEY (id, current_refresh_token_id)
        REFERENCES operator_tokens (device_session_id, id)
        ON DELETE SET NULL (current_refresh_token_id)
        DEFERRABLE INITIALLY DEFERRED
        NOT VALID
      SQL
    end
  end

  def down
    safety_assured do
      execute("ALTER TABLE operator_device_sessions DROP CONSTRAINT fk_operator_device_sessions_on_current_refresh_token_owner")
      remove_foreign_key(:operator_tokens, name: "fk_operator_tokens_on_device_session_id")
    end
  end
end
