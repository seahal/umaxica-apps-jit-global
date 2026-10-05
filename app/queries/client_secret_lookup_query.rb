# frozen_string_literal: true

# Indexed whole-value verification only. The caller must subsequently authorize
# the Client and atomically claim under the canonical flow/browser binding.
class ClientSecretLookupQuery
  class << self
    public

    def call(secret:)
      return nil unless secret.is_a?(String) && secret.valid_encoding? && secret.ascii_only? &&
        ClientSecretCredential::SECRET_FORMAT.match?(secret)

      AppZenithRecord.connected_to(role: :writing) do
        digest = SignSecretLookupDigest.digest(secret)
        now = ClientSecretCredential.database_now
        credential = ClientSecretCredential.available_at(now).find_by(lookup_digest: digest)
        credential if credential&.matches_secret?(secret)
      end
    end
  end
end
