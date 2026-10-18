# frozen_string_literal: true

class SeedCustomerTokenKinds < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute(<<~SQL.squish)
        INSERT INTO customer_token_kinds (id) VALUES
          (1), (2), (3)
        ON CONFLICT (id) DO NOTHING
      SQL
    end
  end

  def down
    safety_assured do
      execute(<<~SQL.squish)
        DELETE FROM customer_token_kinds WHERE id IN (1, 2, 3)
      SQL
    end
  end
end
