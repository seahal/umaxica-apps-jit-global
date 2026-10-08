# typed: false
# frozen_string_literal: true

# Acme/org durable one-shot storage for telephone ceremony results.
# == Schema Information
#
# Table name: operator_telephone_ceremony_transactions
# Database name: org_ticket
#
#  id                       :bigint           not null, primary key
#  actor_ref                :string           not null
#  consumed_at              :datetime
#  expires_at               :datetime         not null
#  grant_jti                :string           not null
#  lock_version             :bigint           default(0), not null
#  normalized_number_digest :string
#  operation                :string           not null
#  result_jti               :string
#  session_ref              :string           not null
#  status                   :string           default("pending"), not null
#  surface                  :string           not null
#  telephone_candidate_ref  :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  transaction_id           :string           not null
#
# Indexes
#
#  idx_on_actor_ref_session_ref_091a0506ae                       (actor_ref,session_ref)
#  idx_on_transaction_id_578b62ae6d                              (transaction_id) UNIQUE
#  index_operator_telephone_ceremony_transactions_on_expires_at  (expires_at)
#  index_operator_telephone_ceremony_transactions_on_grant_jti   (grant_jti) UNIQUE
#  index_operator_telephone_ceremony_transactions_on_result_jti  (result_jti) UNIQUE WHERE (result_jti IS NOT NULL)
#
class OperatorTelephoneCeremonyTransaction < OrgTicketRecord
  include TelephoneCeremonyTransactionable
  include TelephoneCeremonyOtp

  validate :immutable_telephone_otp_terminal_facts

  ceremony_surface "org"
end
