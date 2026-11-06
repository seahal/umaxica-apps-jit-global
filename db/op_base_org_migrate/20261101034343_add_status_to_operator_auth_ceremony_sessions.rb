# frozen_string_literal: true

class AddStatusToOperatorAuthCeremonySessions < ActiveRecord::Migration[8.2]
  STATUS_IDS = [10, 20, 30, 40, 90, 91, 92, 93].freeze

  def up
    create_table(:operator_auth_ceremony_session_statuses, id: :bigint)
    safety_assured { execute("ALTER TABLE public.operator_auth_ceremony_session_statuses SET LOGGED") }
    values = STATUS_IDS.map { |id| "(#{id})" }.join(", ")
    safety_assured do
      execute("INSERT INTO operator_auth_ceremony_session_statuses (id) VALUES #{values}")
    end
    add_column(:operator_auth_ceremony_sessions, :status_id, :bigint)
  end

  def down
    safety_assured do
      remove_column(:operator_auth_ceremony_sessions, :status_id)
      drop_table(:operator_auth_ceremony_session_statuses)
    end
  end
end
