# typed: false
# frozen_string_literal: true

# Acme/com durable one-shot storage for passkey ceremony results.
# == Schema Information
#
# Table name: visitor_passkey_ceremony_transactions
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
#  origin                      :string           not null
#  result_jti                  :string
#  session_ref                 :string           not null
#  status                      :string           default("pending"), not null
#  surface                     :string           not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  rp_id                       :string           not null
#  transaction_id              :string           not null
#
# Indexes
#
#  idx_on_actor_ref_session_ref_6038539041                        (actor_ref,session_ref)
#  index_visitor_passkey_ceremony_transactions_on_expires_at      (expires_at)
#  index_visitor_passkey_ceremony_transactions_on_grant_jti       (grant_jti) UNIQUE
#  index_visitor_passkey_ceremony_transactions_on_result_jti      (result_jti) UNIQUE WHERE (result_jti IS NOT NULL)
#  index_visitor_passkey_ceremony_transactions_on_transaction_id  (transaction_id) UNIQUE
#
class VisitorPasskeyCeremonyTransaction < OpBaseComRecord
  include PasskeyCeremonyTransactionable

  ceremony_surface "com"
end
