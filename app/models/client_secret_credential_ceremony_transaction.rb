# typed: false
# frozen_string_literal: true

# Acme/app durable one-shot storage for secret credential enrollment results.
# == Schema Information
#
# Table name: client_secret_credential_ceremony_transactions
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
#  idx_on_actor_ref_session_ref_1470aaddcc  (actor_ref,session_ref)
#  idx_on_expires_at_6a705a7bb7             (expires_at)
#  idx_on_grant_jti_58e101b1d8              (grant_jti) UNIQUE
#  idx_on_result_jti_b20b4e2f25             (result_jti) UNIQUE WHERE (result_jti IS NOT NULL)
#  idx_on_transaction_id_b63311dbbc         (transaction_id) UNIQUE
#
class ClientSecretCredentialCeremonyTransaction < OpBaseAppRecord
  include SecretCredentialCeremonyTransactionable

  ceremony_surface "app"
end
