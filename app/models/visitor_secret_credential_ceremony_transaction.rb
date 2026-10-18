# typed: false
# frozen_string_literal: true

# Acme/com durable one-shot storage for secret credential enrollment results.
# == Schema Information
#
# Table name: visitor_secret_credential_ceremony_transactions
# Database name: op_base_com
#
#  id                          :bigint           not null, primary key
#  actor_ref                   :string           not null
#  consumed_at                 :datetime
#  credential_candidate_digest :string
#  credential_candidate_ref    :string
#  expires_at                  :datetime         not null
#  grant_jti                   :string           not null
#  lock_version                :bigint           default(0), not null
#  operation                   :string           not null
#  result_jti                  :string
#  session_ref                 :string           not null
#  status                      :string           default("pending"), not null
#  surface                     :string           not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  transaction_id              :string           not null
#
# Indexes
#
#  idx_on_actor_ref_session_ref_b6a6aeb3f9  (actor_ref,session_ref)
#  idx_on_expires_at_bcbf526321             (expires_at)
#  idx_on_grant_jti_3ce786ea06              (grant_jti) UNIQUE
#  idx_on_result_jti_9191bba74d             (result_jti) UNIQUE WHERE (result_jti IS NOT NULL)
#  idx_on_transaction_id_759e16c588         (transaction_id) UNIQUE
#
class VisitorSecretCredentialCeremonyTransaction < OpBaseComRecord
  include SecretCredentialCeremonyTransactionable

  ceremony_surface "com"
end
