# frozen_string_literal: true

# D-134: one SIGN_FLOW_HALTED row per ORG normal sign-in transaction and halt generation.
class AddSignFlowHaltedExactlyOnce < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  SIGN_FLOW_HALTED = 18

  def change
    add_check_constraint(
      :operator_chronicles,
      "event_id <> #{SIGN_FLOW_HALTED} OR " \
      "(context ? 'transaction_public_id' AND context ? 'halt_generation')",
      name: "chk_operator_chronicles_sign_flow_halted_keys", validate: false,
    )
    add_index(
      :operator_chronicles,
      "(context->>'transaction_public_id'), (context->>'halt_generation')",
      unique: true, where: "event_id = #{SIGN_FLOW_HALTED}",
      name: "uniq_operator_chronicles_sign_flow_halted", algorithm: :concurrently,
    )
  end
end
