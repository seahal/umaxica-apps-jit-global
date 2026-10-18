# typed: false
# frozen_string_literal: true

class CreateVisitorOidcIdentityBindings < ActiveRecord::Migration[8.2]
  REGISTERED_AUDIENCES = %w(base-com-ww core-com warp-com).freeze
  CANONICAL_AUDIENCES = %w(base base-selector-bootstrap).freeze

  def up
    create_table(:visitor_oidc_identity_bindings) do |t|
      t.references(:visitor_identity, null: false, foreign_key: { on_delete: :restrict })
      t.string(:issuer, null: false)
      t.string(:subject, null: false)
      t.string(:audience, null: false)
      t.timestamps

      t.index(
        %i(issuer subject audience), unique: true,
                                     name: "idx_visitor_oidc_identity_bindings_subject",
      )
      t.index(
        %i(visitor_identity_id issuer audience), unique: true,
                                                 name: "idx_visitor_oidc_identity_bindings_identity",
      )
    end unless table_exists?(:visitor_oidc_identity_bindings)

    validate_legacy_rows!
    safety_assured do
      execute(<<~SQL.squish)
        INSERT INTO visitor_oidc_identity_bindings
          (visitor_identity_id, issuer, subject, audience, created_at, updated_at)
        SELECT id, issuer, subject, audience, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        FROM visitor_identities
        WHERE audience IN (#{REGISTERED_AUDIENCES.map { |value| connection.quote(value) }.join(", ")})
        ON CONFLICT DO NOTHING
      SQL
    end
  end

  def down
    drop_table(:visitor_oidc_identity_bindings, if_exists: true)
  end

  private

  def validate_legacy_rows!
    known = REGISTERED_AUDIENCES + CANONICAL_AUDIENCES
    expected_issuer = connection.quote(OidcIssuer.for_resource_type("visitor"))
    invalid = select_values(<<~SQL.squish)
      SELECT identities.id
      FROM visitor_identities identities
      LEFT JOIN visitors actors ON actors.id = identities.source_record_id
      WHERE identities.audience NOT IN (#{known.map { |value| connection.quote(value) }.join(", ")})
         OR actors.id IS NULL
         OR (identities.audience IN (#{REGISTERED_AUDIENCES.map { |value| connection.quote(value) }.join(", ")})
             AND identities.issuer <> #{expected_issuer})
      ORDER BY identities.id
    SQL
    return if invalid.empty?

    raise ActiveRecord::MigrationError,
          "visitor identity rows fail OIDC registration validation (ids=#{invalid.join(",")})"
  end
end
