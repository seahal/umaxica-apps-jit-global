# frozen_string_literal: true

# WU-7 D-57 (two.md section 4.7): Base binds consent and Web Push to a host-only browser binding
# cookie (`__Host-preference_binding`). The digest of a 32-byte CSPRNG value, never the value
# itself, is stored per preference cookie row so a later anonymous request re-presenting that cookie
# is what makes stored consent readable. The digest is replaying-safe: it carries no preference
# value, and its uniqueness Universe is "one active binding row per cookie value".
class AddPreferencesBrowserBindingDigests < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured { add_column(:com_preference_cookies, :browser_binding_digest, :string, limit: 64) }
    return unless column_exists?(:com_preference_cookies, :browser_binding_digest)

    safety_assured do
      add_index(
        :com_preference_cookies, :browser_binding_digest, unique: true, algorithm: :concurrently,
                                                          name: "idx_com_pref_cookies_on_binding_digest",
      )
    end

  end

  def down
    if index_exists?(:com_preference_cookies, :browser_binding_digest, name: "idx_com_pref_cookies_on_binding_digest")
      safety_assured do
        remove_index(:com_preference_cookies, name: "idx_com_pref_cookies_on_binding_digest", algorithm: :concurrently)
      end
    end
    safety_assured { remove_column(:com_preference_cookies, :browser_binding_digest) }
  end
end
