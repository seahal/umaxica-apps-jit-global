# frozen_string_literal: true

# The Client is resolved before this query. App Secrets are deliberately not
# globally enumerable by a whole-value digest: equal values on two Clients are
# independent credentials.
class ClientSecretLookupQuery
  class << self
    public

    def call(client:, secret:)
      return nil unless client.is_a?(Client)
      return nil unless secret.is_a?(String) && secret.valid_encoding? && secret.ascii_only? &&
        ClientSecretCredential::SECRET_FORMAT.match?(secret)

      AppZenithRecord.connected_to(role: :writing) do
        now = ClientSecretCredential.database_now
        eligible_issuance_ids = ClientSecretIssuance.where(client_id: client.id)
          .where("sign_up_flow_ref IS NULL OR signup_completed_at IS NOT NULL").select(:id)
        ClientSecretCredential.available_at(now).where(client_id: client.id, issuance_id: eligible_issuance_ids)
          .order(:id).find do |credential|
          credential.matches_secret?(secret)
        end
      end
    end
  end
end
