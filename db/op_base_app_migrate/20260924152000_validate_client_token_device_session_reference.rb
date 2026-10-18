# frozen_string_literal: true

class ValidateClientTokenDeviceSessionReference < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("SET LOCAL lock_timeout = '5s'")
      execute("SET LOCAL statement_timeout = '30min'")

      validate_foreign_key(:client_tokens, name: "fk_client_tokens_on_device_session_id")
    end
  end

  # PostgreSQL cannot mark a validated constraint NOT VALID. The prior migration
  # removes the constraints if this migration is rolled back.
  def down
    # There is no reversible validation state transition.
  end
end
