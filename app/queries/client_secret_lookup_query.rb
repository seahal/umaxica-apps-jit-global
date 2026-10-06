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
        ClientSecretCredential.available_at(now).where(client_id: client.id).order(:id).find do |credential|
          next unless credential.issuance&.sign_up_flow_ref.nil? || credential.issuance.signup_completed_at

          credential.matches_secret?(secret)
        end
      end
    end
  end
end
