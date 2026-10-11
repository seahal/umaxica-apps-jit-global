# typed: false
# frozen_string_literal: true

class ClientPersonaUsageGrant < AppRpRecord
  belongs_to :client_persona, inverse_of: :usage_grants
  belongs_to :client, inverse_of: :client_persona_usage_grants
end
