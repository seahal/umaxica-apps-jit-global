# typed: false
# frozen_string_literal: true

class VisitorOidcIdentityBinding < ComRpRecord
  belongs_to :visitor_identity, inverse_of: :oidc_identity_bindings

  validates :issuer, :subject, :audience, presence: true
  validates :visitor_identity_id, uniqueness: { scope: %i(issuer audience) }
  validates :subject, uniqueness: { scope: %i(issuer audience) }
end
