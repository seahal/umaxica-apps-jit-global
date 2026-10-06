# typed: false
# frozen_string_literal: true

class OperatorOidcIdentityBinding < OrgRpRecord
  belongs_to :operator_identity, inverse_of: :oidc_identity_bindings

  validates :issuer, :subject, :audience, presence: true
  validates :operator_identity_id, uniqueness: { scope: %i(issuer audience) }
  validates :subject, uniqueness: { scope: %i(issuer audience) }
end
