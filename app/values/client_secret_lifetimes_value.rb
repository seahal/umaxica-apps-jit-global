# frozen_string_literal: true

# New operational values require explicit configuration; the proposal is documented separately.
class ClientSecretLifetimesValue
  class << self
    public

    def issuance_ttl
      seconds!("APP_SECRET_ISSUANCE_TTL_SECONDS").seconds
    end

    def purge_delay
      seconds!("APP_SECRET_PURGE_DELAY_SECONDS").seconds
    end

    def proof_retention
      seconds!("APP_SECRET_PROOF_RETENTION_SECONDS").seconds
    end

    def outbox_retention
      seconds!("APP_SECRET_OUTBOX_RETENTION_SECONDS").seconds
    end

    private

    def seconds!(key)
      value = Integer(ENV.fetch(key), 10)
      raise ArgumentError, "#{key} must be positive" unless value.positive?

      value
    end
  end
end
