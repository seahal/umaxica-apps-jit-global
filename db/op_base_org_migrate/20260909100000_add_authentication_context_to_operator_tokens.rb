# frozen_string_literal: true

# Records which sign-in ceremony established an org session. NULL means the
# ordinary Normal context, which is what every session predating Emergency
# Access was: the column narrows authority, so the absent value is the
# unrestricted one and no backfill is required.
class AddAuthenticationContextToOperatorTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  CONTEXTS = %w(normal emergency).freeze

  def change
    add_column(:operator_tokens, :authentication_context, :string)

    add_index(
      :operator_tokens,
      :authentication_context,
      algorithm: :concurrently,
    )

    add_check_constraint(
      :operator_tokens,
      "authentication_context IS NULL OR authentication_context IN (" \
      "#{CONTEXTS.map { |c| "'#{c}'" }.join(", ")})",
      name: "chk_operator_tokens_authentication_context",
      validate: false,
    )
  end
end
