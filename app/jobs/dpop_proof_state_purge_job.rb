# typed: false
# frozen_string_literal: true

# Deletes expired DPoP proof-state rows from the per-surface ticket databases.
#
# `*_dpop_proof_states` rows are written on stateful DPoP paths (refresh,
# step-up, login, token-exchange) for JTI replay detection and to back issued
# DPoP-Nonces. Every row carries `expires_at` (`DpopProofStateable::TTL_SECONDS`,
# 300s) and is meaningless once past it.
#
# These tables are intentionally NOT handled by `RetentionPurgeJob`, which keys
# on `purge_eligible_at` (account-retention lifecycle). Proof-state rows have no
# `purge_eligible_at`; without this job they would grow unbounded. The `expires_at`
# index on each table keeps the delete scan cheap.
class DpopProofStatePurgeJob < ApplicationJob
  queue_as :retention

  PURGEABLE_MODELS = [
    ClientDpopProofState,
    OperatorDpopProofState,
    VisitorDpopProofState,
  ].freeze

  def perform(batch_size: 500)
    now = Time.current

    PURGEABLE_MODELS.each do |model|
      # delete_all routes to the model's connection; force the writing role so
      # the deletes never land on a read replica.
      ActiveRecord::Base.connected_to(role: :writing) do
        model.where(model.arel_table[:expires_at].lt(now))
          .in_batches(of: batch_size)
          .delete_all
      end
    end
  end
end
