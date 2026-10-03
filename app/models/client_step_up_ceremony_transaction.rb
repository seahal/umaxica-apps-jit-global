# typed: false
# frozen_string_literal: true

# Acme/app durable one-shot storage for step-up ceremony results.
# == Schema Information
#
# Table name: client_step_up_ceremony_transactions
# Database name: app_ticket
#
#  id              :bigint           not null, primary key
#  aal             :string
#  actor_ref       :string           not null
#  allowed_methods :text             not null
#  consumed_at     :datetime
#  expires_at      :datetime         not null
#  grant_jti       :string           not null
#  lock_version    :bigint           default(0), not null
#  method          :string
#  required_aal    :string           not null
#  required_scope  :string           not null
#  resource_ref    :string
#  result_jti      :string
#  return_to       :string
#  session_ref     :string           not null
#  status          :string           default("pending"), not null
#  surface         :string           not null
#  verified_at     :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  transaction_id  :string           not null
#
# Indexes
#
#  idx_on_actor_ref_session_ref_4f24c7001d                       (actor_ref,session_ref)
#  index_client_step_up_ceremony_transactions_on_expires_at      (expires_at)
#  index_client_step_up_ceremony_transactions_on_grant_jti       (grant_jti) UNIQUE
#  index_client_step_up_ceremony_transactions_on_required_scope  (required_scope)
#  index_client_step_up_ceremony_transactions_on_result_jti      (result_jti) UNIQUE WHERE (result_jti IS NOT NULL)
#  index_client_step_up_ceremony_transactions_on_transaction_id  (transaction_id) UNIQUE
#
class ClientStepUpCeremonyTransaction < AppTicketRecord
  include StepUpCeremonyTransactionable

  ceremony_surface "app"

  private

  def permitted_ceremony_methods = %w(passkey totp email_otp)
end
