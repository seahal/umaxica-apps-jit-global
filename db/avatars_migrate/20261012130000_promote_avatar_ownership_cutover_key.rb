# frozen_string_literal: true

class PromoteAvatarOwnershipCutoverKey < ActiveRecord::Migration[8.2]
  TABLE_NAME = "avatar_ownership_cutovers"
  INDEX_NAME = "index_avatar_ownership_cutovers_on_id"
  PRIMARY_KEY_NAME = "avatar_ownership_cutovers_pkey"

  def up
    safety_assured do
      execute(<<~SQL.squish)
        ALTER TABLE #{TABLE_NAME}
        ADD CONSTRAINT #{PRIMARY_KEY_NAME}
        PRIMARY KEY USING INDEX #{INDEX_NAME}
      SQL
    end
  end

  def down
    safety_assured do
      execute(<<~SQL.squish)
        ALTER TABLE #{TABLE_NAME}
        DROP CONSTRAINT #{PRIMARY_KEY_NAME}
      SQL
      add_index(TABLE_NAME, :id, unique: true, name: INDEX_NAME)
    end
  end
end
