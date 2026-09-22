# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_oidc_authorization_transactions
# Database name: app_ticket
#
#  id                         :bigint           not null, primary key
#  acr                        :string
#  actor_ref                  :string
#  auth_method                :string
#  authenticated_at           :datetime
#  authorization_grant_redeemed_at :datetime
#  base_finalized_at          :datetime
#  browser_session_ref        :string
#  code_challenge             :string           not null
#  code_challenge_method      :string           not null
#  consumed_at                :datetime
#  expires_at                 :datetime         not null
#  intent                     :string           not null
#  login_challenge            :string           not null
#  login_challenge_expires_at :datetime         not null
#  nonce                      :string           not null
#  redirect_uri               :string           not null
#  result_consumed_at         :datetime
#  result_digest              :string
#  result_expires_at          :datetime
#  result_generation          :integer          default(0), not null
#  response_type              :string           not null
#  scope                      :string           not null
#  session_ref                :string
#  state                      :string           not null
#  status                     :string           not null
#  surface                    :string           not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  client_id                  :string           not null
#  transaction_id             :string           not null
#
# Indexes
#
#  idx_on_client_id_login_challenge_8f71e56454                     (client_id,login_challenge)
#  idx_on_login_challenge_91d464d261                               (login_challenge) UNIQUE
#  index_client_oidc_authorization_transactions_on_transaction_id  (transaction_id) UNIQUE
#
class ClientOidcAuthorizationTransaction < AppTicketRecord
  include OidcAuthorizationTransactionable

  oidc_authorization_surface "app"
end
