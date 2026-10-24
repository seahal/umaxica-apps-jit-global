# frozen_string_literal: true

# WU-14 (D-33): the verified ID Token a Base RP grant presents as the end-session id_token_hint.
# It arrives at the RP callback, after the grant exists, so it lives in its own row: no row means no
# hint yet, and no column is left NULL to mean it.
class CreateOpOrgGrantLogoutHints < ActiveRecord::Migration[8.2]
  def change
    create_table(:op_org_grant_logout_hints) do |t|
      t.references(
        :grant, null: false, index: { unique: true },
                foreign_key: { to_table: :op_org_grants, on_delete: :cascade },
      )
      t.text(:id_token, null: false)
      t.timestamps
    end
  end
end
