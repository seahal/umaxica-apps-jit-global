# frozen_string_literal: true

class CreateDeadIdentifierHistories < ActiveRecord::Migration[8.2]
  public

  def change
    %i(operator_email_histories operator_telephone_histories).each do |table|
      create_table table do |t|
        t.bigint :staff_id, null: false
        t.string :fingerprint, null: false
        t.datetime :attached_at, null: false
        t.datetime :detached_at, null: false
        t.datetime :created_at, null: false
        t.index :staff_id
        t.foreign_key :operators, column: :staff_id, on_delete: :restrict
      end
    end
  end
end
