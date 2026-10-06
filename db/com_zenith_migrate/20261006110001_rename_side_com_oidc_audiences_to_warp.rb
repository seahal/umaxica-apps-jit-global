# typed: false
# frozen_string_literal: true

class RenameSideComOidcAudiencesToWarp < ActiveRecord::Migration[8.2]
  def up
    raise ActiveRecord::MigrationError, "conflicting com identity audiences" if conflicting_audiences?

    safety_assured do
      execute <<~SQL
        UPDATE visitor_identities
        SET audience = 'warp-com', updated_at = CURRENT_TIMESTAMP
        WHERE audience = 'side-com'
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
      FROM visitor_identities old_rows
      JOIN visitor_identities new_rows
        ON new_rows.issuer = old_rows.issuer
       AND new_rows.subject = old_rows.subject
       AND new_rows.audience = 'warp-com'
      WHERE old_rows.audience = 'side-com'
    SQL
  end
end
