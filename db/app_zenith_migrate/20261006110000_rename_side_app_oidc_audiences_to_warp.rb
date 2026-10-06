# typed: false
# frozen_string_literal: true

class RenameSideAppOidcAudiencesToWarp < ActiveRecord::Migration[8.2]
  def up
    raise ActiveRecord::MigrationError, "conflicting app identity audiences" if conflicting_audiences?

    safety_assured do
      execute <<~SQL
        UPDATE client_identities
        SET audience = 'warp-app', updated_at = CURRENT_TIMESTAMP
        WHERE audience = 'side-app'
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Side-to-Warp audience migration is irreversible"
  end

  private

  def conflicting_audiences?
    connection.select_value(<<~SQL).to_i.positive?
      SELECT COUNT(*)
      FROM client_identities old_rows
      JOIN client_identities new_rows
        ON new_rows.issuer = old_rows.issuer
       AND new_rows.subject = old_rows.subject
       AND new_rows.audience = 'warp-app'
      WHERE old_rows.audience = 'side-app'
    SQL
  end
end
