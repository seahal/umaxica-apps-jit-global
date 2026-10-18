# frozen_string_literal: true
class ExtendAppSignUpCyclesForTicketContract < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_cycle_column :entry_method, :string
    add_cycle_column :pending_contact_type, :string
    add_cycle_column :pending_contact_id, :bigint
    add_cycle_column :social_provider, :string
    add_cycle_column :completed_requirements, :jsonb, null: false, default: {}
    add_cycle_column :cleanup_token, :string, null: false, default: ""
    add_cycle_column :failed_at, :datetime
    add_cycle_column :cancelled_at, :datetime

    add_index :app_sign_up_cycles,
              [:status_id, :expires_at],
              name: "index_app_sign_up_cycles_on_status_id_and_expires_at",
              if_not_exists: true,
              algorithm: :concurrently
    add_index :app_sign_up_cycles,
              :pending_contact_id,
              name: "index_app_sign_up_cycles_on_pending_contact_id",
              if_not_exists: true,
              algorithm: :concurrently
    add_index :app_sign_up_cycles,
              :cleanup_token,
              name: "index_app_sign_up_cycles_on_cleanup_token",
              if_not_exists: true,
              algorithm: :concurrently
  end

  def down
    remove_index :app_sign_up_cycles,
                 name: "index_app_sign_up_cycles_on_cleanup_token",
                 if_exists: true,
                 algorithm: :concurrently
    remove_index :app_sign_up_cycles,
                 name: "index_app_sign_up_cycles_on_pending_contact_id",
                 if_exists: true,
                 algorithm: :concurrently
    remove_index :app_sign_up_cycles,
                 name: "index_app_sign_up_cycles_on_status_id_and_expires_at",
                 if_exists: true,
                 algorithm: :concurrently

    remove_cycle_column :cancelled_at
    remove_cycle_column :failed_at
    remove_cycle_column :cleanup_token
    remove_cycle_column :completed_requirements
    remove_cycle_column :social_provider
    remove_cycle_column :pending_contact_id
    remove_cycle_column :pending_contact_type
    remove_cycle_column :entry_method
  end

  private

  def add_cycle_column(name, type, **options)
    return if column_exists?(:app_sign_up_cycles, name)

    add_column :app_sign_up_cycles, name, type, **options
  end

  def remove_cycle_column(name)
    return unless column_exists?(:app_sign_up_cycles, name)

    remove_column :app_sign_up_cycles, name
  end
end
