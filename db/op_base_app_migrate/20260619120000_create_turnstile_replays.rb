# typed: false
# frozen_string_literal: true

class CreateTurnstileReplays < ActiveRecord::Migration[8.2]
  def change
    create_table :turnstile_replays do |t|
      t.string :ceremony_id, null: false
      t.string :token_digest, null: false
      t.string :action
      t.string :hostname
      t.string :cdata
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
    end

    add_index :turnstile_replays, :token_digest, unique: true
    add_index :turnstile_replays, :expires_at
  end
end
