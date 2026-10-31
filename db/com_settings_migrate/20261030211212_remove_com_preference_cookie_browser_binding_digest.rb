# frozen_string_literal: true

class RemoveComPreferenceCookieBrowserBindingDigest < ActiveRecord::Migration[8.2]
  def up
    safety_assured { execute("LOCK TABLE com_preference_cookies IN ACCESS EXCLUSIVE MODE") }
    if select_value("SELECT EXISTS (SELECT 1 FROM com_preference_cookies WHERE browser_binding_digest IS NOT NULL)")
      raise ActiveRecord::IrreversibleMigration, "legacy browser binding digests require an approved data disposition"
    end

    safety_assured { remove_column(:com_preference_cookies, :browser_binding_digest) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "restore the database backup to recover legacy binding digests"
  end
end
