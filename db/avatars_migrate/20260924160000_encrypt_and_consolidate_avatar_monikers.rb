# frozen_string_literal: true

class EncryptAndConsolidateAvatarMonikers < ActiveRecord::Migration[8.2]
  def up
    # The encrypted representation replaces plaintext in this one-time, destructive transition.
    # Production application remains gated on the reviewed data inventory and rollout window.
    safety_assured do
      change_column(:avatar_monikers, :moniker, :string, limit: 512, null: false)
    end
    remove_index(:avatar_monikers, name: "index_avatar_monikers_on_avatar_moniker_status_id")
    remove_foreign_key(:avatar_monikers, column: :avatar_moniker_status_id)
    remove_check_constraint(
      :avatar_monikers,
      name: "chk_avatar_monikers_avatar_moniker_status_id_positive",
    )
    safety_assured { remove_column(:avatar_monikers, :avatar_moniker_status_id) }
    safety_assured { remove_column(:avatar_monikers, :set_by_actor_id) }
    safety_assured { drop_table(:avatar_moniker_statuses) }
    safety_assured { remove_column(:avatars, :moniker) }

    encrypt_existing_monikers!
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Avatar moniker values are encrypted and the legacy Avatar name authority was removed"
  end

  private

  def encrypt_existing_monikers!
    last_id = 0

    loop do
      rows = connection.select_all(<<~SQL.squish)
        SELECT id, moniker
          FROM avatar_monikers
         WHERE id > #{connection.quote(last_id)}
         ORDER BY id
         LIMIT 500
      SQL
      break if rows.empty?

      rows.each do |row|
        plaintext = row.fetch("moniker")
        raise "Avatar moniker row #{row.fetch("id")} is already encrypted" if
          ActiveRecord::Encryption.encryptor.encrypted?(plaintext)

        ciphertext = ActiveRecord::Encryption.encryptor.encrypt(plaintext)
        connection.update(<<~SQL.squish)
          UPDATE avatar_monikers
             SET moniker = #{connection.quote(ciphertext)}
           WHERE id = #{connection.quote(row.fetch("id"))}
        SQL
        last_id = row.fetch("id").to_i
      end
    end
  end
end
