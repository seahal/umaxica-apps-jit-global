# frozen_string_literal: true

class BackfillClientOidcAuthorizationTransactionStatuses < ActiveRecord::Migration[8.2]
  STATUS_IDS = { "pending" => 10, "authenticated" => 20, "consumed" => 30, "canceled" => 90 }.freeze

  def up
    invalid = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM client_oidc_authorization_transactions
      WHERE status IS NULL OR status NOT IN (#{STATUS_IDS.keys.map { |status| connection.quote(status) }.join(", ")})
    SQL
    raise ActiveRecord::MigrationError, "unknown client OIDC authorization status values (rows=#{invalid})" unless invalid.zero?

    inconsistent = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM client_oidc_authorization_transactions
      WHERE (status = 'pending' AND (authenticated_at IS NOT NULL OR consumed_at IS NOT NULL OR
        canceled_at IS NOT NULL OR base_finalized_at IS NOT NULL OR browser_session_ref IS NOT NULL))
         OR (status = 'authenticated' AND (authenticated_at IS NULL OR consumed_at IS NOT NULL OR
        canceled_at IS NOT NULL OR base_finalized_at IS NOT NULL OR browser_session_ref IS NOT NULL))
         OR (status = 'consumed' AND (authenticated_at IS NULL OR consumed_at IS NULL OR canceled_at IS NOT NULL OR
        ((base_finalized_at IS NULL) <> (browser_session_ref IS NULL))))
         OR (status = 'canceled' AND (canceled_at IS NULL OR consumed_at IS NOT NULL OR
        base_finalized_at IS NOT NULL OR browser_session_ref IS NOT NULL))
    SQL
    raise ActiveRecord::MigrationError,
          "client OIDC authorization status facts are inconsistent (rows=#{inconsistent})" unless inconsistent.zero?

    safety_assured do
      STATUS_IDS.each do |status, status_id|
        execute(<<~SQL.squish)
          UPDATE client_oidc_authorization_transactions
          SET status_id = #{status_id}
          WHERE status = #{connection.quote(status)}
        SQL
      end
    end

    incomplete = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM client_oidc_authorization_transactions
      WHERE status_id IS NULL OR status_id NOT IN (#{STATUS_IDS.values.join(", ")})
    SQL
    raise ActiveRecord::MigrationError, "client OIDC authorization status backfill is incomplete (rows=#{incomplete})" unless incomplete.zero?
  end

  def down
    safety_assured { execute("UPDATE client_oidc_authorization_transactions SET status_id = NULL") }
  end
end
