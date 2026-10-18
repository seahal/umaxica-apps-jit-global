# typed: false
# frozen_string_literal: true

class ValidateHardenedClientSessionLimitResolutionWaitingSlot < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(
      :client_session_limit_resolution_transactions,
      name: "chk_client_resolution_waiting_slot_state",
    )
  end
end
