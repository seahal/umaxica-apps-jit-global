# typed: false
# frozen_string_literal: true

# Acme/com durable one-shot storage for step-up ceremony results.
# == Schema Information
#
# Table name: visitor_step_up_ceremony_transactions
# Database name: com_ticket
#
#  id              :bigint           not null, primary key
#  aal             :string           # @deprecated evidence label; remove after explicit-evidence consumers migrate
#  actor_ref       :string           not null
#  allowed_methods :text             not null
#  consumed_at     :datetime
#  expires_at      :datetime         not null
#  grant_jti       :string           not null
#  lock_version    :bigint           default(0), not null
#  method          :string
#  required_aal    :string           not null        # @deprecated label; remove after AAL ledger retirement
#  required_scope  :string           not null
#  step_up_required :boolean         not null
#  user_verification_required :boolean not null
#  full_reauthentication_required :boolean not null
#  audience        :string
#  token_binding   :string
#  require_session_binding :boolean  not null
#  tenant_ref      :string
#  resource_ref    :string
#  result_jti      :string
#  return_to       :string
#  session_ref     :string           not null
#  status          :string           default("pending"), not null
#  surface         :string           not null
#  verified_at     :datetime
#  user_verified   :boolean
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  transaction_id  :string           not null
#
# Indexes
#
#  idx_on_actor_ref_session_ref_7e0a1d7d4c                        (actor_ref,session_ref)
#  index_visitor_step_up_ceremony_transactions_on_expires_at      (expires_at)
#  index_visitor_step_up_ceremony_transactions_on_grant_jti       (grant_jti) UNIQUE
#  index_visitor_step_up_ceremony_transactions_on_required_scope  (required_scope)
#  index_visitor_step_up_ceremony_transactions_on_result_jti      (result_jti) UNIQUE WHERE (result_jti IS NOT NULL)
#  index_visitor_step_up_ceremony_transactions_on_transaction_id  (transaction_id) UNIQUE
#
class VisitorStepUpCeremonyTransaction < ComTicketRecord
  include StepUpCeremonyTransactionable

  ceremony_surface "com"

  private

  def permitted_ceremony_methods = %w(passkey email_otp)
end
