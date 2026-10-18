# typed: false
# frozen_string_literal: true

# Deletes expired one-time reveal rows from `security_one_time_reveals`.
#
# Each row holds an encrypted payload -- a recovery secret credential is the current caller --
# together with the digests that decide who may read it once. `IdentityOneTimeReveal` writes one
# per issue and `SecurityOneTimeReveal.consume` refuses any row past `expires_at`, so from that
# moment the row can no longer reveal anything and is only retained ciphertext.
#
# The predicate is `expires_at` alone, matching SecurityConsumedJtiPurgeJob. A consumed row is
# already spent, but deleting on `consumed_at` would add a second rule for no gain: the window is
# fifteen minutes and the expiry sweep collects it either way.
#
# Not part of RetentionPurgeJob, which keys on `purge_eligible_at` (the account-retention lifecycle);
# these rows have no `purge_eligible_at` and would otherwise grow without bound. The `expires_at` index
# keeps the delete scan cheap.
class SecurityOneTimeRevealPurgeJob < ApplicationJob
  queue_as :retention

  def perform(batch_size: 500)
    now = Time.current

    # delete_all routes to the model's connection; force the writing role so the
    # deletes never land on a read replica.
    ActiveRecord::Base.connected_to(role: :writing) do
      SecurityOneTimeReveal
        .where(SecurityOneTimeReveal.arel_table[:expires_at].lt(now))
        .in_batches(of: batch_size)
        .delete_all
    end
  end
end
