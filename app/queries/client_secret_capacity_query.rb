# frozen_string_literal: true

class ClientSecretCapacityQuery
  class << self
    public

    # Mutation callers take the Client lock first and supply one writer timestamp.
    # These counts are facts about credentials and reservations, not account access.
    def call(client:, at:)
      unless client.is_a?(Client) && client.persisted?
        raise ArgumentError, "Secret capacity requires a persisted app Client"
      end
      unless at.is_a?(Time) || at.is_a?(ActiveSupport::TimeWithZone)
        raise ArgumentError, "Secret capacity requires an explicit writer timestamp"
      end

      AppZenithRecord.connected_to(role: :writing) do
        active = ClientSecretCredential.available_at(at).where(client_id: client.id).count
        reserved = ClientSecretIssuance.where(client_id: client.id, confirmed_at: nil, canceled_at: nil)
          .where("planned_count > 0 AND expires_at > ? AND discard_at > ?", at, at).sum(:planned_count)
        ClientSecretIssuanceCountValue.new(active_count: active, reserved_count: reserved)
      end
    end
  end
end
