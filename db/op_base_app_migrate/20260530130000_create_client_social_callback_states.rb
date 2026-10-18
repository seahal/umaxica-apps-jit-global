# typed: false
# frozen_string_literal: true

class CreateClientSocialCallbackStates < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    create_table :client_social_callback_states, if_not_exists: true do |t|
      t.string :state_digest, null: false
      t.string :provider, null: false
      t.string :intent
      t.datetime :issued_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
    end

    add_index :client_social_callback_states, :state_digest, unique: true,
                                                            algorithm: :concurrently,
                                                            if_not_exists: true
    add_index :client_social_callback_states, :expires_at, algorithm: :concurrently, if_not_exists: true
  end
end
