# typed: false
# frozen_string_literal: true

class ClientOidcIdentityBinding < AppRpRecord
  belongs_to :client_identity, inverse_of: :oidc_identity_bindings

  validates :issuer, :subject, :audience, presence: true
  validates :client_identity_id, uniqueness: { scope: %i(issuer audience) }
  validates :subject, uniqueness: { scope: %i(issuer audience) }
end
