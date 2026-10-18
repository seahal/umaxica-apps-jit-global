# frozen_string_literal: true

class ValidateClientTokenDeviceSessionActorForeignKey < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("SET LOCAL lock_timeout = '5s'")
      execute("SET LOCAL statement_timeout = '30min'")

      validate_foreign_key(:client_tokens, name: "fk_client_tokens_on_user_id_and_device_session_id")
    end
  end

  def down
    # PostgreSQL cannot reverse validation without dropping the constraint.
  end
end
