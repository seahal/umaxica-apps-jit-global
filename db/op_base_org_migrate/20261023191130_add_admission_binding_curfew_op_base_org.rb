# frozen_string_literal: true

# D-159/D-168: this cycle is applied to rebuilt databases. There is no backfill or default.
# The empty-table NOT NULL addition is deliberately strict if applied to populated bindings.
class AddAdmissionBindingCurfewOpBaseOrg < ActiveRecord::Migration[8.2]
  public

  def change
    # Both DDL statements are one migration transaction: no nullable runtime phase or default.
    add_column(:operator_auth_admission_bindings, :curfew_at, :datetime)
    safety_assured { change_column_null(:operator_auth_admission_bindings, :curfew_at, false) }
  end
end
