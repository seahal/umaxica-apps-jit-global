# frozen_string_literal: true

# R5-WU18: the shared authentication-context vocabulary (AuthenticationContextValue) is
# normal/standby. Standby is an Org-only sign-in, so no app flow should hold it; the constraint is
# kept in step with the vocabulary so a retired `emergency` value cannot be stored here either.
class RenameAppAuthenticationContextVocabularyToStandby < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLE = :client_sign_in_flows
  NAME = "client_local_authentication_context_valid"

  public

  def up = replace_vocabulary(from: "emergency", to: "standby")

  def down = replace_vocabulary(from: "standby", to: "emergency")

  private

  def replace_vocabulary(from:, to:)
    remove_check_constraint(TABLE, name: NAME)
    safety_assured do
      execute("UPDATE #{TABLE} SET authentication_context = '#{to}' WHERE authentication_context = '#{from}'")
    end
    add_check_constraint(
      TABLE, "authentication_context IS NULL OR authentication_context IN ('normal', '#{to}')",
      name: NAME, validate: false,
    )
    validate_check_constraint(TABLE, name: NAME)
  end
end
