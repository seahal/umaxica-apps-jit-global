# frozen_string_literal: true

class AddStatusToClientAuthCeremonySessions < ActiveRecord::Migration[8.2]
  STATUS_IDS = [10, 20, 30, 40, 90, 91, 92, 93].freeze

  def up
    create_table(:client_auth_ceremony_session_statuses, id: :bigint)
    safety_assured { execute("ALTER TABLE public.client_auth_ceremony_session_statuses SET LOGGED") }
    values = STATUS_IDS.map { |id| "(#{id})" }.join(", ")
    safety_assured do
      execute("INSERT INTO client_auth_ceremony_session_statuses (id) VALUES #{values}")
    end
    add_column(:client_auth_ceremony_sessions, :status_id, :bigint)
  end

  def down
    safety_assured do
      remove_column(:client_auth_ceremony_sessions, :status_id)
      drop_table(:client_auth_ceremony_session_statuses)
    end
  end
end
