# typed: false
# frozen_string_literal: true

class ClientPersonaDelegationGrant < AppRpRecord
  belongs_to :client_persona, inverse_of: :delegation_grants
  belongs_to :client, inverse_of: :client_persona_delegation_grants
end
