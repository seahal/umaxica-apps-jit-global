# frozen_string_literal: true

class AddStateReferenceToOperatorOidcAuthorizationTransactions < ActiveRecord::Migration[8.2]
  STATUS_IDS = [10, 20, 30, 90].freeze

  def up
    create_table(:operator_oidc_authorization_transaction_statuses, id: :bigint)
    safety_assured { execute("ALTER TABLE public.operator_oidc_authorization_transaction_statuses SET LOGGED") }
    values = STATUS_IDS.map { |id| "(#{id})" }.join(", ")
    safety_assured do
      execute("INSERT INTO operator_oidc_authorization_transaction_statuses (id) VALUES #{values}")
    end
    add_column(:operator_oidc_authorization_transactions, :status_id, :bigint)
  end

  def down
    safety_assured do
      remove_column(:operator_oidc_authorization_transactions, :status_id)
      drop_table(:operator_oidc_authorization_transaction_statuses)
    end
  end
end
