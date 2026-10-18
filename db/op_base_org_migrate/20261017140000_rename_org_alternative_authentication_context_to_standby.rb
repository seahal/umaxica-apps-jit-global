# frozen_string_literal: true

# R5-WU18 coherent terminology: the Org alternative sign-in context is `standby`, not `emergency`.
# Development/test data is rebuilt rather than preserved (one.md 1.2A); existing rows are converted
# so the new constraint validates. A pre-R5 `emergency` access-token claim is not converted: it is
# refused as an unknown context (AuthenticationContextValue).
class RenameOrgAlternativeAuthenticationContextToStandby < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  CONSTRAINTS = {
    operator_sign_in_flows: "operator_local_authentication_context_valid",
    operator_tokens: "chk_operator_tokens_authentication_context",
  }.freeze

  public

  def up
    CONSTRAINTS.each do |table, name|
      remove_check_constraint(table, name:)
      safety_assured do
        execute("UPDATE #{table} SET authentication_context = 'standby' WHERE authentication_context = 'emergency'")
      end
      add_check_constraint(
        table, "authentication_context IS NULL OR authentication_context IN ('normal', 'standby')",
        name:, validate: false,
      )
      validate_check_constraint(table, name:)
    end
  end

  def down
    CONSTRAINTS.each do |table, name|
      remove_check_constraint(table, name:)
      safety_assured do
        execute("UPDATE #{table} SET authentication_context = 'emergency' WHERE authentication_context = 'standby'")
      end
      add_check_constraint(
        table, "authentication_context IS NULL OR authentication_context IN ('normal', 'emergency')",
        name:, validate: false,
      )
      validate_check_constraint(table, name:)
    end
  end
end
