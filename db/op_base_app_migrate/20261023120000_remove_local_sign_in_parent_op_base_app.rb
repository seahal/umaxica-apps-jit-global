# frozen_string_literal: true

# D-60 (WU-01): the entry-less Local Sign-in Flow is removed. Admission bindings keep only the OIDC
# authorization and Ticket parents, and ceremony sessions lose the Local flow references. Owner
# decision D-168 authorizes the destructive change; no stored value is carried over.
class RemoveLocalSignInParentOpBaseApp < ActiveRecord::Migration[8.2]
  BINDINGS = :client_auth_admission_bindings
  CEREMONIES = :client_auth_ceremony_sessions
  HANDOFF = %w(authentication_handoff invitation_handoff).freeze
  TICKET = %w(step_up_handoff reauthentication_handoff bootstrap_handoff credential_registration_handoff
              credential_change_handoff).freeze
  LOCAL = %w(local_sign_in local_sign_up).freeze

  def up
    remove_check_constraint(BINDINGS, name: "client_admission_bindings_one_parent")
    remove_check_constraint(BINDINGS, name: "client_admission_bindings_parent_purpose")
    remove_index(BINDINGS, name: "idx_client_admission_bindings_live_sign_in")
    safety_assured { remove_column(BINDINGS, :sign_in_flow_id) }
    add_check_constraint(
      BINDINGS, "num_nonnulls(authorization_transaction_id, step_up_ceremony_transaction_id) = 1",
      name: "client_admission_bindings_one_parent", validate: false,
    )
    add_check_constraint(BINDINGS, parent_purpose_expression(local: false), name: "client_admission_bindings_parent_purpose", validate: false)

    remove_check_constraint(CEREMONIES, name: "client_auth_ceremony_purpose_exclusive")
    remove_check_constraint(CEREMONIES, name: "client_auth_ceremony_transaction_exclusive")
    remove_check_constraint(CEREMONIES, name: "client_auth_admission_purpose_valid")
    safety_assured do
      remove_column(CEREMONIES, :local_sign_in_flow_ref)
      remove_column(CEREMONIES, :local_sign_up_flow_ref)
    end
    add_check_constraint(
      CEREMONIES, "num_nonnulls(authorization_transaction_ref, step_up_ceremony_transaction_ref) <= 1",
      name: "client_auth_ceremony_transaction_exclusive", validate: false,
    )
    add_check_constraint(CEREMONIES, purpose_valid_expression(HANDOFF + TICKET), name: "client_auth_admission_purpose_valid", validate: false)
  end

  def down
    remove_check_constraint(CEREMONIES, name: "client_auth_admission_purpose_valid")
    remove_check_constraint(CEREMONIES, name: "client_auth_ceremony_transaction_exclusive")
    add_column(CEREMONIES, :local_sign_up_flow_ref, :string)
    add_column(CEREMONIES, :local_sign_in_flow_ref, :string)
    add_foreign_key(
      CEREMONIES, :client_sign_up_flows, column: :local_sign_up_flow_ref, primary_key: :public_id,
                                         on_delete: :restrict,
    )
    add_foreign_key(
      CEREMONIES, :client_sign_in_flows, column: :local_sign_in_flow_ref, primary_key: :public_id,
                                         on_delete: :restrict,
    )
    add_check_constraint(CEREMONIES, purpose_valid_expression(LOCAL + HANDOFF + TICKET), name: "client_auth_admission_purpose_valid")
    add_check_constraint(
      CEREMONIES,
      "num_nonnulls(authorization_transaction_ref, local_sign_in_flow_ref, local_sign_up_flow_ref, " \
      "step_up_ceremony_transaction_ref) <= 1",
      name: "client_auth_ceremony_transaction_exclusive",
    )
    add_check_constraint(
      CEREMONIES, "num_nonnulls(authorization_transaction_ref, local_sign_in_flow_ref, local_sign_up_flow_ref) <= 1",
      name: "client_auth_ceremony_purpose_exclusive",
    )

    remove_check_constraint(BINDINGS, name: "client_admission_bindings_parent_purpose")
    remove_check_constraint(BINDINGS, name: "client_admission_bindings_one_parent")
    add_reference(BINDINGS, :sign_in_flow, foreign_key: { to_table: :client_sign_in_flows }, index: false)
    add_index(
      BINDINGS, :sign_in_flow_id, unique: true, name: "idx_client_admission_bindings_live_sign_in",
                                  where: "sign_in_flow_id IS NOT NULL AND retired_at IS NULL AND redeemed_at IS NULL",
    )
    add_check_constraint(
      BINDINGS, "num_nonnulls(sign_in_flow_id, authorization_transaction_id, step_up_ceremony_transaction_id) = 1",
      name: "client_admission_bindings_one_parent",
    )
    add_check_constraint(BINDINGS, parent_purpose_expression(local: true), name: "client_admission_bindings_parent_purpose")
  end

  private

  def purpose_valid_expression(purposes)
    "admission_purpose IS NULL OR admission_purpose IN (#{purposes.map { |value| "'#{value}'" }.join(", ")})"
  end

  def parent_purpose_expression(local:)
    clauses = [
      "(authorization_transaction_id IS NULL OR purpose IN (#{HANDOFF.map { |value| "'#{value}'" }.join(", ")}))",
      "(step_up_ceremony_transaction_id IS NULL OR purpose IN (#{TICKET.map { |value| "'#{value}'" }.join(", ")}))",
    ]
    clauses.unshift("(sign_in_flow_id IS NULL OR purpose IN ('local_sign_in', 'local_sign_up'))") if local
    clauses.join(" AND ")
  end
end
