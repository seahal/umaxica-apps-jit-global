# typed: false
# frozen_string_literal: true

class CreateOperatorOidcIdentityBindings < ActiveRecord::Migration[8.2]
  REGISTERED_AUDIENCES = %w(base-org-ww core-org edit-org warp-org).freeze
  CANONICAL_AUDIENCES = %w(base base-selector-bootstrap).freeze

  def up
    create_table(:operator_oidc_identity_bindings) do |t|
      t.references(:operator_identity, null: false, foreign_key: { on_delete: :restrict })
      t.string(:issuer, null: false)
      t.string(:subject, null: false)
      t.string(:audience, null: false)
      t.timestamps

      t.index(
        %i(issuer subject audience), unique: true,
                                     name: "idx_operator_oidc_identity_bindings_subject",
      )
      t.index(
        %i(operator_identity_id issuer audience), unique: true,
                                                  name: "idx_operator_oidc_identity_bindings_identity",
      )
    end unless table_exists?(:operator_oidc_identity_bindings)

    validate_legacy_rows!
    safety_assured do
      execute(<<~SQL.squish)
        INSERT INTO operator_oidc_identity_bindings
          (operator_identity_id, issuer, subject, audience, created_at, updated_at)
        SELECT id, issuer, subject, audience, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        FROM operator_identities
        WHERE audience IN (#{REGISTERED_AUDIENCES.map { |value| connection.quote(value) }.join(", ")})
        ON CONFLICT DO NOTHING
      SQL
    end
  end

  def down
    drop_table(:operator_oidc_identity_bindings, if_exists: true)
  end

  private

  def validate_legacy_rows!
    known = REGISTERED_AUDIENCES + CANONICAL_AUDIENCES
    expected_issuer = connection.quote(OidcIssuer.for_resource_type("operator"))
    invalid = select_values(<<~SQL.squish)
      SELECT identities.id
      FROM operator_identities identities
      LEFT JOIN operators actors ON actors.id = identities.source_record_id
      WHERE identities.audience NOT IN (#{known.map { |value| connection.quote(value) }.join(", ")})
         OR actors.id IS NULL
         OR (identities.audience IN (#{REGISTERED_AUDIENCES.map { |value| connection.quote(value) }.join(", ")})
             AND identities.issuer <> #{expected_issuer})
      ORDER BY identities.id
    SQL
    return if invalid.empty?

    raise ActiveRecord::MigrationError,
          "operator identity rows fail OIDC registration validation (ids=#{invalid.join(",")})"
  end
end
