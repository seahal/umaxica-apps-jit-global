# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_oidc_authorization_transactions
# Database name: com_ticket
#
#  id                         :bigint           not null, primary key
#  acr                        :string
#  actor_ref                  :string
#  auth_method                :string
#  authenticated_at           :datetime
#  authorization_grant_redeemed_at :datetime
#  base_finalized_at           :datetime
#  browser_session_ref         :string
#  code_challenge             :string           not null
#  code_challenge_method      :string           not null
#  consumed_at                :datetime
#  expires_at                 :datetime         not null
#  intent                     :string           not null
#  login_challenge            :string           not null
#  login_challenge_expires_at :datetime         not null
#  nonce                      :string           not null
#  redirect_uri               :string           not null
#  result_consumed_at          :datetime
#  result_digest               :string
#  result_expires_at           :datetime
#  result_generation           :integer          default(0), not null
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
#  idx_on_client_id_login_challenge_8056723634  (client_id,login_challenge)
#  idx_on_login_challenge_8c09aab77b            (login_challenge) UNIQUE
#  idx_on_transaction_id_391ee3ac66             (transaction_id) UNIQUE
#
class VisitorOidcAuthorizationTransaction < ComTicketRecord
  include OidcAuthorizationTransactionable

  oidc_authorization_surface "com"
end
