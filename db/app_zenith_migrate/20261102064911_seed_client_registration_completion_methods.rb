# frozen_string_literal: true

class SeedClientRegistrationCompletionMethods < ActiveRecord::Migration[8.2]
  class MethodRow < ActiveRecord::Base
    self.table_name = "client_registration_completion_methods"
  end

  public

  def up
    [
      { id: 1, key: "email" }, { id: 2, key: "telephone" },
      { id: 3, key: "google" }, { id: 4, key: "apple" },
    ].each { |attributes| MethodRow.create!(attributes) }
  end

  def down
    if connection.select_value("SELECT EXISTS (SELECT 1 FROM client_registration_completions)")
      raise ActiveRecord::IrreversibleMigration, "Registration completion history requires an approved recovery plan"
    end

    MethodRow.where(id: 1..4).delete_all
  end
end
