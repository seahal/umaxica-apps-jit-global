# frozen_string_literal: true

# Each realm loads this migration in its own database context; the class is not shared at runtime.
# rubocop:disable Lint/DuplicateMethods
class CreateDeadIdentifierHistories < ActiveRecord::Migration[8.2]
  public

  def change
    %i(client_email_histories client_telephone_histories).each do |table|
      create_table(table) do |t|
        t.bigint(:user_id, null: false)
        t.string(:fingerprint, null: false)
        t.datetime(:attached_at, null: false)
        t.datetime(:detached_at, null: false)
        t.datetime(:created_at, null: false)
        t.index(:user_id)
        t.foreign_key(:clients, column: :user_id, on_delete: :restrict)
      end
    end
  end
end

# rubocop:enable Lint/DuplicateMethods
