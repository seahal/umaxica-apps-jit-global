# typed: false
# frozen_string_literal: true

# Acme/app durable one-shot storage for TOTP enrollment ceremony results.
# == Schema Information
#
# Table name: client_totp_ceremony_transactions
# Database name: op_base_app
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
#  idx_on_actor_ref_session_ref_e256c5d4a6                    (actor_ref,session_ref)
#  index_client_totp_ceremony_transactions_on_expires_at      (expires_at)
#  index_client_totp_ceremony_transactions_on_grant_jti       (grant_jti) UNIQUE
#  index_client_totp_ceremony_transactions_on_result_jti      (result_jti) UNIQUE WHERE (result_jti IS NOT NULL)
#  index_client_totp_ceremony_transactions_on_transaction_id  (transaction_id) UNIQUE
#
class ClientTotpCeremonyTransaction < OpBaseAppRecord
  include TotpCeremonyTransactionable

  ceremony_surface "app"
end
