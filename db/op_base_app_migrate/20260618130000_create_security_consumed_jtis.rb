# typed: false
# frozen_string_literal: true

class CreateSecurityConsumedJtis < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    create_table :security_consumed_jtis, if_not_exists: true do |t|
      t.string :purpose, null: false
      t.string :issuer, null: false
      t.string :jti_digest, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :security_consumed_jtis, %i(purpose issuer jti_digest), unique: true,
                                                                        algorithm: :concurrently,
                                                                        if_not_exists: true
    add_index :security_consumed_jtis, :expires_at, algorithm: :concurrently, if_not_exists: true
  end
end
