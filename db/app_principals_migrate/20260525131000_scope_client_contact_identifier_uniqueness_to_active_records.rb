# frozen_string_literal: true
class ScopeClientContactIdentifierUniquenessToActiveRecords < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index :client_emails, name: :index_client_emails_on_address_digest, algorithm: :concurrently, if_exists: true
    add_index :client_emails,
              :address_digest,
              unique: true,
              where: "address_digest IS NOT NULL AND user_email_status_id <> 4",
              name: :index_client_emails_on_active_address_digest,
              algorithm: :concurrently,
              if_not_exists: true

    remove_index :client_telephones, name: :index_client_telephones_on_number_digest, algorithm: :concurrently, if_exists: true
    add_index :client_telephones,
              :number_digest,
              unique: true,
              where: "number_digest IS NOT NULL AND user_identity_telephone_status_id <> 4",
              name: :index_client_telephones_on_active_number_digest,
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :client_emails, name: :index_client_emails_on_active_address_digest, algorithm: :concurrently,
                                  if_exists: true
    add_index :client_emails,
              :address_digest,
              unique: true,
              where: "address_digest IS NOT NULL",
              name: :index_client_emails_on_address_digest,
              algorithm: :concurrently,
              if_not_exists: true

    remove_index :client_telephones, name: :index_client_telephones_on_active_number_digest, algorithm: :concurrently,
                                      if_exists: true
    add_index :client_telephones,
              :number_digest,
              unique: true,
              where: "number_digest IS NOT NULL",
              name: :index_client_telephones_on_number_digest,
              algorithm: :concurrently,
              if_not_exists: true
  end
end
