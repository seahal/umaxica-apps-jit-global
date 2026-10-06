# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: acme_logout_transactions
# Database name: app_ticket
#
#  id                  :bigint           not null, primary key
#  actor_ref           :string
#  callback_state      :string
#  completion_url      :text             not null
#  completed_steps     :jsonb            not null
#  expected_step       :string           not null
#  expires_at          :datetime         not null
#  failed_at           :datetime
#  finalized_at        :datetime
#  initiating_client_id :string          not null
#  origin_surface      :string           not null
#  public_id           :string(21)       not null
#  session_ref         :string
#  status              :string           default("initiated"), not null
#  workflow            :string           default("legacy"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_acme_logout_transactions_on_expires_at          (expires_at)
#  index_acme_logout_transactions_on_origin_surface      (origin_surface)
#  index_acme_logout_transactions_on_public_id           (public_id) UNIQUE
#  index_acme_logout_transactions_on_status              (status)
#
class AcmeLogoutTransaction < AppTicketRecord
  include AcmeLogoutTransactionable

  def logout_challenge = public_id
end
