# frozen_string_literal: true

class RequireNonblankAvatarOwnershipTransferIds < ActiveRecord::Migration[8.2]
  def change
    add_check_constraint :avatar_ownership_transfers,
                         "public_id ~ '[^[:space:]]' AND " \
                         "from_owner_collective_public_id ~ '[^[:space:]]' AND " \
                         "to_owner_collective_public_id ~ '[^[:space:]]' AND " \
                         "request_actor_public_id ~ '[^[:space:]]' AND " \
                         "(accept_actor_public_id IS NULL OR accept_actor_public_id ~ '[^[:space:]]') AND " \
                         "(cancel_actor_public_id IS NULL OR cancel_actor_public_id ~ '[^[:space:]]')",
                         name: "chk_avatar_ownership_transfer_nonblank_ids",
                         validate: false
  end
end
