# frozen_string_literal: true

class AddVisitorTokenDeviceSessionActorForeignKey < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("SET LOCAL lock_timeout = '5s'")
      execute("SET LOCAL statement_timeout = '30min'")

      add_foreign_key(
        :visitor_tokens, :visitor_device_sessions,
        column: %i(visitor_id device_session_id),
        primary_key: %i(visitor_id id),
        name: "fk_visitor_tokens_on_visitor_id_and_device_session_id",
        on_delete: :restrict,
        validate: false,
      )
    end
  end

  def down
    safety_assured do
      remove_foreign_key(:visitor_tokens, name: "fk_visitor_tokens_on_visitor_id_and_device_session_id")
    end
  end
end
