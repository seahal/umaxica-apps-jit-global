# typed: false
# frozen_string_literal: true

# Acme/org durable one-shot storage for secret credential enrollment results.
# == Schema Information
#
# Table name: operator_secret_credential_ceremony_transactions
# Database name: op_base_org
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
#  idx_on_actor_ref_session_ref_dce233ec55  (actor_ref,session_ref)
#  idx_on_expires_at_feac3d8c3e             (expires_at)
#  idx_on_grant_jti_3681a4d031              (grant_jti) UNIQUE
#  idx_on_result_jti_6830d7796f             (result_jti) UNIQUE WHERE (result_jti IS NOT NULL)
#  idx_on_transaction_id_c4257bc798         (transaction_id) UNIQUE
#
class OperatorSecretCredentialCeremonyTransaction < OpBaseOrgRecord
  include SecretCredentialCeremonyTransactionable

  ceremony_surface "org"
end
