# frozen_string_literal: true

class RemoveAppSecretLookupDigest < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      remove_index :client_secret_credentials,
                   name: "index_client_secret_credentials_on_lookup_digest",
                   algorithm: :concurrently,
                   if_exists: true
      remove_column :client_secret_credentials, :lookup_digest, :string, if_exists: true
    end
  end

  def down
    safety_assured do
      add_column :client_secret_credentials, :lookup_digest, :string
      add_index :client_secret_credentials, :lookup_digest,
                name: "index_client_secret_credentials_on_lookup_digest",
                algorithm: :concurrently
    end
  end
end
