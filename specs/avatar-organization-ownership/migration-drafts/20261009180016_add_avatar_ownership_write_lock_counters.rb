# frozen_string_literal: true

class AddAvatarOwnershipWriteLockCounters < ActiveRecord::Migration[8.2]
  def change
    enable_extension("btree_gist")

    # Not an ownership fact. Every ownership-period and transfer-request write increments it so
    # that a REPEATABLE READ or SERIALIZABLE transaction holding an older snapshot fails with a
    # serialization error instead of deciding ownership from rows it cannot see.
    add_column(:avatars, :ownership_write_lock_counter, :bigint, null: false, default: 0)
    add_column(:avatar_groups, :ownership_write_lock_counter, :bigint, null: false, default: 0)
  end
end
