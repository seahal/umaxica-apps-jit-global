# frozen_string_literal: true

class AddStateReferenceToClientOidcAuthorizationTransactions < ActiveRecord::Migration[8.2]
  STATUS_IDS = [10, 20, 30, 90].freeze

  def up
    create_table(:client_oidc_authorization_transaction_statuses, id: :bigint)
    safety_assured { execute("ALTER TABLE public.client_oidc_authorization_transaction_statuses SET LOGGED") }
    values = STATUS_IDS.map { |id| "(#{id})" }.join(", ")
    safety_assured do
      execute("INSERT INTO client_oidc_authorization_transaction_statuses (id) VALUES #{values}")
    end
    add_column(:client_oidc_authorization_transactions, :status_id, :bigint)
  end

  def down
    safety_assured do
      remove_column(:client_oidc_authorization_transactions, :status_id)
      drop_table(:client_oidc_authorization_transaction_statuses)
    end
  end
end
