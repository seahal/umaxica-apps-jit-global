# typed: false
# frozen_string_literal: true

class CreateClientOidcIdentityBindings < ActiveRecord::Migration[8.2]
  REGISTERED_AUDIENCES = %w(
    app-android-rp app-ios-rp base-app-ww core-app warp-app
  ).freeze
  CANONICAL_AUDIENCES = %w(base base-selector-bootstrap).freeze

  def up
    create_table(:client_oidc_identity_bindings) do |t|
      t.references(:client_identity, null: false, foreign_key: { on_delete: :restrict })
      t.string(:issuer, null: false)
      t.string(:subject, null: false)
      t.string(:audience, null: false)
      t.timestamps

      t.index(
        %i(issuer subject audience), unique: true,
                                     name: "idx_client_oidc_identity_bindings_subject",
      )
      t.index(
        %i(client_identity_id issuer audience), unique: true,
                                                name: "idx_client_oidc_identity_bindings_identity",
      )
    end unless table_exists?(:client_oidc_identity_bindings)

    validate_legacy_rows!
    safety_assured do
      execute(<<~SQL.squish)
        INSERT INTO client_oidc_identity_bindings
          (client_identity_id, issuer, subject, audience, created_at, updated_at)
        SELECT id, issuer, subject, audience, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        FROM client_identities
        WHERE audience IN (#{REGISTERED_AUDIENCES.map { |value| connection.quote(value) }.join(", ")})
        ON CONFLICT DO NOTHING
      SQL
    end
  end

  def down
    drop_table(:client_oidc_identity_bindings, if_exists: true)
  end

  private

  def validate_legacy_rows!
    known = REGISTERED_AUDIENCES + CANONICAL_AUDIENCES
    expected_issuer = connection.quote(OidcIssuer.for_resource_type("client"))
    invalid = select_values(<<~SQL.squish)
      SELECT identities.id
      FROM client_identities identities
      LEFT JOIN clients actors ON actors.id = identities.source_record_id
      WHERE identities.audience NOT IN (#{known.map { |value| connection.quote(value) }.join(", ")})
         OR actors.id IS NULL
         OR (identities.audience IN (#{REGISTERED_AUDIENCES.map { |value| connection.quote(value) }.join(", ")})
             AND identities.issuer <> #{expected_issuer})
      ORDER BY identities.id
    SQL
    return if invalid.empty?

    raise ActiveRecord::MigrationError,
          "client identity rows fail OIDC registration validation (ids=#{invalid.join(",")})"
  end
end
