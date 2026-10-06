# typed: false
# frozen_string_literal: true

class AddExplicitVisitorStepUpRequirementEvidence < ActiveRecord::Migration[8.2]
  def up
    add_requirement_columns
    add_evidence_columns
    add_token_columns
    backfill_requirement_snapshot
  end

  def down
    remove_token_columns
    remove_evidence_columns
    remove_requirement_columns
  end

  private

  def add_requirement_columns
    add_column :visitor_step_up_ceremony_transactions, :step_up_required, :boolean, null: false, default: true unless column_exists?(:visitor_step_up_ceremony_transactions, :step_up_required)
    add_column :visitor_step_up_ceremony_transactions, :user_verification_required, :boolean, null: false, default: false unless column_exists?(:visitor_step_up_ceremony_transactions, :user_verification_required)
    add_column :visitor_step_up_ceremony_transactions, :full_reauthentication_required, :boolean, null: false, default: false unless column_exists?(:visitor_step_up_ceremony_transactions, :full_reauthentication_required)
    add_column :visitor_step_up_ceremony_transactions, :audience, :string unless column_exists?(:visitor_step_up_ceremony_transactions, :audience)
    add_column :visitor_step_up_ceremony_transactions, :token_binding, :string unless column_exists?(:visitor_step_up_ceremony_transactions, :token_binding)
    add_column :visitor_step_up_ceremony_transactions, :require_session_binding, :boolean, null: false, default: true unless column_exists?(:visitor_step_up_ceremony_transactions, :require_session_binding)
    add_column :visitor_step_up_ceremony_transactions, :tenant_ref, :string unless column_exists?(:visitor_step_up_ceremony_transactions, :tenant_ref)
  end

  def add_evidence_columns
    add_column :visitor_step_up_ceremony_transactions, :user_verified, :boolean unless column_exists?(:visitor_step_up_ceremony_transactions, :user_verified)
  end

  def add_token_columns
    add_column :visitor_tokens, :last_step_up_user_verified, :boolean unless column_exists?(:visitor_tokens, :last_step_up_user_verified)
    add_column :visitor_tokens, :last_step_up_credential_ref, :string unless column_exists?(:visitor_tokens, :last_step_up_credential_ref)
    add_column :visitor_tokens, :last_step_up_full_reauthentication, :boolean unless column_exists?(:visitor_tokens, :last_step_up_full_reauthentication)
    add_column :visitor_tokens, :last_step_up_resource_ref, :string unless column_exists?(:visitor_tokens, :last_step_up_resource_ref)
    add_column :visitor_tokens, :last_step_up_tenant_ref, :string unless column_exists?(:visitor_tokens, :last_step_up_tenant_ref)
  end

  def backfill_requirement_snapshot
    safety_assured do
      execute <<~SQL.squish
        UPDATE visitor_step_up_ceremony_transactions
        SET step_up_required = (purpose NOT IN ('bootstrap', 'credential_registration')),
            audience = 'step_up:' || surface,
            token_binding = session_ref,
            require_session_binding = TRUE
        WHERE audience IS NULL OR token_binding IS NULL
      SQL
    end
  end

  def remove_token_columns
    remove_column :visitor_tokens, :last_step_up_tenant_ref if column_exists?(:visitor_tokens, :last_step_up_tenant_ref)
    remove_column :visitor_tokens, :last_step_up_resource_ref if column_exists?(:visitor_tokens, :last_step_up_resource_ref)
    remove_column :visitor_tokens, :last_step_up_full_reauthentication if column_exists?(:visitor_tokens, :last_step_up_full_reauthentication)
    remove_column :visitor_tokens, :last_step_up_credential_ref if column_exists?(:visitor_tokens, :last_step_up_credential_ref)
    remove_column :visitor_tokens, :last_step_up_user_verified if column_exists?(:visitor_tokens, :last_step_up_user_verified)
  end

  def remove_evidence_columns
    remove_column :visitor_step_up_ceremony_transactions, :user_verified if column_exists?(:visitor_step_up_ceremony_transactions, :user_verified)
  end

  def remove_requirement_columns
    remove_column :visitor_step_up_ceremony_transactions, :tenant_ref if column_exists?(:visitor_step_up_ceremony_transactions, :tenant_ref)
    remove_column :visitor_step_up_ceremony_transactions, :require_session_binding if column_exists?(:visitor_step_up_ceremony_transactions, :require_session_binding)
    remove_column :visitor_step_up_ceremony_transactions, :token_binding if column_exists?(:visitor_step_up_ceremony_transactions, :token_binding)
    remove_column :visitor_step_up_ceremony_transactions, :audience if column_exists?(:visitor_step_up_ceremony_transactions, :audience)
    remove_column :visitor_step_up_ceremony_transactions, :full_reauthentication_required if column_exists?(:visitor_step_up_ceremony_transactions, :full_reauthentication_required)
    remove_column :visitor_step_up_ceremony_transactions, :user_verification_required if column_exists?(:visitor_step_up_ceremony_transactions, :user_verification_required)
    remove_column :visitor_step_up_ceremony_transactions, :step_up_required if column_exists?(:visitor_step_up_ceremony_transactions, :step_up_required)
  end
end
