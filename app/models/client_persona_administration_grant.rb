# typed: false
# frozen_string_literal: true

class ClientPersonaAdministrationGrant < AppRpRecord
  belongs_to :client_persona, inverse_of: :administration_grants
  belongs_to :client, inverse_of: :client_persona_administration_grants
end
