# frozen_string_literal: true

class CreateDeadIdentifierHistories < ActiveRecord::Migration[8.2]
  public

  def change
    %i(visitor_email_histories visitor_telephone_histories).each do |table|
      create_table table do |t|
        t.bigint :visitor_id, null: false
        t.string :fingerprint, null: false
        t.datetime :attached_at, null: false
        t.datetime :detached_at, null: false
        t.datetime :created_at, null: false
        t.index :visitor_id
        t.foreign_key :visitors, column: :visitor_id, on_delete: :restrict
      end
    end
  end
end
