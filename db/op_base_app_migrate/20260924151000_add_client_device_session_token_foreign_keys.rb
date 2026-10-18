# frozen_string_literal: true

class AddClientDeviceSessionTokenForeignKeys < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("SET LOCAL lock_timeout = '5s'")
      execute("SET LOCAL statement_timeout = '30min'")

      add_foreign_key(
        :client_tokens,
        :client_device_sessions,
        column: :device_session_id,
        name: "fk_client_tokens_on_device_session_id",
        on_delete: :restrict,
        validate: false,
      )

      execute(<<~SQL.squish)
        ALTER TABLE client_device_sessions
        ADD CONSTRAINT fk_client_device_sessions_on_current_refresh_token_owner
        FOREIGN KEY (id, current_refresh_token_id)
        REFERENCES client_tokens (device_session_id, id)
        ON DELETE SET NULL (current_refresh_token_id)
        DEFERRABLE INITIALLY DEFERRED
        NOT VALID
      SQL
    end
  end

  def down
    safety_assured do
      execute("ALTER TABLE client_device_sessions DROP CONSTRAINT fk_client_device_sessions_on_current_refresh_token_owner")
      remove_foreign_key(:client_tokens, name: "fk_client_tokens_on_device_session_id")
    end
  end
end
