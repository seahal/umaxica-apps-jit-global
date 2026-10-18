# frozen_string_literal: true

class ValidateOperatorCurrentRefreshTokenOwner < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("SET LOCAL lock_timeout = '5s'")
      execute("SET LOCAL statement_timeout = '30min'")
      execute("ALTER TABLE operator_device_sessions VALIDATE CONSTRAINT fk_operator_device_sessions_on_current_refresh_token_owner")
    end
  end

  def down
    # PostgreSQL cannot reverse validation without dropping the constraint.
  end
end
