# typed: false
# frozen_string_literal: true

class ClientPersonaViewGrant < AppRpRecord
  belongs_to :client_persona, inverse_of: :view_grants
  belongs_to :client, inverse_of: :client_persona_view_grants
end
