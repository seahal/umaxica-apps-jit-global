# typed: false
# frozen_string_literal: true

# Deletes expired replay-prevention rows from `security_consumed_jtis`.
#
# Every row records that a single-use token was consumed: OIDC logout requests
# and logout tokens, Jump RT return tokens, sign-out notices, and OIDC client
# assertions. The row only has to outlive the token it guards, which is what
# `expires_at` records -- past that point the token is rejected on `exp` before
# the replay check is ever reached, so the row can no longer prevent anything.
#
# Deleting earlier than `expires_at` would re-open the replay window, so this
# job's only predicate is that timestamp. It is deliberately not part of
# `RetentionPurgeJob`, which keys on `purged_at` (the account-retention
# lifecycle); these rows have no `purged_at` and would otherwise grow without
# bound. Client assertions in particular land here once per token request. The
# `expires_at` index keeps the delete scan cheap.
class SecurityConsumedJtiPurgeJob < ApplicationJob
  queue_as :retention

  def perform(batch_size: 500)
    now = Time.current

    # delete_all routes to the model's connection; force the writing role so the
    # deletes never land on a read replica.
    ActiveRecord::Base.connected_to(role: :writing) do
      SecurityConsumedJti
        .where(SecurityConsumedJti.arel_table[:expires_at].lt(now))
        .in_batches(of: batch_size)
        .delete_all
    end
  end
end
