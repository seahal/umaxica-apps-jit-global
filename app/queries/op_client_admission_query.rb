# typed: false
# frozen_string_literal: true

# Whether the realm OP admits an exact RP client at its current contract epoch (R5-WU19). Read-only.
# No row, a disabled row, or a row for an older epoch is closed.
class OpClientAdmissionQuery
  REALMS = {
    "app" => [OpAppClientActivation, OpAppProtocolEpoch],
    "com" => [OpComClientActivation, OpComProtocolEpoch],
    "org" => [OpOrgClientActivation, OpOrgProtocolEpoch],
  }.freeze

  class << self
    public

    def admitted?(client_id:)
      cell = RpCellBinding.for_client(client_id)
      activation_class, epoch_class = REALMS.fetch(cell.realm)
      activation_class.connection_class_for_self.connected_to(role: :writing) do
        activation_class.exists?(
          client_id: cell.client_id, contract_epoch: epoch_class.current_contract_epoch, enabled: true,
        )
      end
    rescue RpCellBinding::UnknownCell
      false
    end
  end
end
