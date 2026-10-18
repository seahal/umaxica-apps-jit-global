# frozen_string_literal: true

class AddClientTokenDeviceSessionActorForeignKey < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("SET LOCAL lock_timeout = '5s'")
      execute("SET LOCAL statement_timeout = '30min'")

      add_foreign_key(
        :client_tokens, :client_device_sessions,
        column: %i(user_id device_session_id),
        primary_key: %i(user_id id),
        name: "fk_client_tokens_on_user_id_and_device_session_id",
        on_delete: :restrict,
        validate: false,
      )
    end
  end

  def down
    safety_assured do
      remove_foreign_key(:client_tokens, name: "fk_client_tokens_on_user_id_and_device_session_id")
    end
  end
end
