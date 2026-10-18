# frozen_string_literal: true

class CreateAvatarOwnershipTransfers < ActiveRecord::Migration[8.2]
  def change
    create_table :avatar_ownership_transfers do |t|
      t.references :avatar, null: false, index: false, foreign_key: { on_delete: :restrict }
      t.string :public_id, limit: 21, null: false
      t.string :from_owner_surface, null: false
      t.string :from_owner_collective_public_id, null: false
      t.string :to_owner_surface, null: false
      t.string :to_owner_collective_public_id, null: false
      t.string :state, null: false
      t.datetime :requested_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :cancelled_at
      t.datetime :expired_at
      t.string :request_actor_surface, null: false
      t.string :request_actor_public_id, null: false
      t.string :accept_actor_surface
      t.string :accept_actor_public_id
      t.string :cancel_actor_surface
      t.string :cancel_actor_public_id

      t.timestamps

      t.index :public_id, unique: true
      t.index :avatar_id, unique: true, where: "state = 'pending'",
                         name: "idx_avatar_ownership_transfers_one_pending"
    end

    add_check_constraint :avatar_ownership_transfers,
                         "from_owner_surface IN ('app', 'org') AND " \
                         "to_owner_surface IN ('app', 'org') AND " \
                         "request_actor_surface IN ('app', 'org') AND " \
                         "from_owner_surface = request_actor_surface",
                         name: "chk_avatar_ownership_transfer_surfaces"
    add_check_constraint :avatar_ownership_transfers,
                         "(from_owner_surface, from_owner_collective_public_id) <> " \
                         "(to_owner_surface, to_owner_collective_public_id)",
                         name: "chk_avatar_ownership_transfer_owner_changed"
    add_check_constraint :avatar_ownership_transfers,
                         "requested_at < expires_at AND expires_at - requested_at <= interval '5 days'",
                         name: "chk_avatar_ownership_transfer_expiry"
    add_check_constraint :avatar_ownership_transfers,
                         "state IN ('pending', 'accepted', 'cancelled', 'expired')",
                         name: "chk_avatar_ownership_transfer_state"
    add_check_constraint :avatar_ownership_transfers,
                         terminal_state_check,
                         name: "chk_avatar_ownership_transfer_terminal_facts"
  end

  private

  def terminal_state_check
    <<~SQL.squish
      (state = 'pending' AND accepted_at IS NULL AND cancelled_at IS NULL AND expired_at IS NULL
        AND accept_actor_surface IS NULL AND accept_actor_public_id IS NULL
        AND cancel_actor_surface IS NULL AND cancel_actor_public_id IS NULL)
      OR
      (state = 'accepted' AND accepted_at IS NOT NULL AND cancelled_at IS NULL AND expired_at IS NULL
        AND accept_actor_surface = to_owner_surface AND accept_actor_public_id IS NOT NULL
        AND cancel_actor_surface IS NULL AND cancel_actor_public_id IS NULL)
      OR
      (state = 'cancelled' AND accepted_at IS NULL AND cancelled_at IS NOT NULL AND expired_at IS NULL
        AND accept_actor_surface IS NULL AND accept_actor_public_id IS NULL
        AND cancel_actor_surface = from_owner_surface AND cancel_actor_public_id IS NOT NULL)
      OR
      (state = 'expired' AND accepted_at IS NULL AND cancelled_at IS NULL AND expired_at IS NOT NULL
        AND accept_actor_surface IS NULL AND accept_actor_public_id IS NULL
        AND cancel_actor_surface IS NULL AND cancel_actor_public_id IS NULL)
    SQL
  end
end
