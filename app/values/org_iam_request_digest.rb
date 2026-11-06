# frozen_string_literal: true

require "digest"
require "json"

# The operation ID names one exact administrative request. Only this digest, not the input,
# is stored in the principal outcome and Chronicle metadata.
class OrgIamRequestDigest
  VERSION = 1

  class << self
    public

    def grant(actor_public_id:, subject_public_id:, capability:, duration_seconds:, reason_code:, ticket_id:)
      require_strings!(actor_public_id, subject_public_id, capability, reason_code)
      raise ArgumentError, "duration must be a positive integer" unless duration_seconds.is_a?(Integer) &&
        duration_seconds.positive?
      unless ticket_id.nil? || (ticket_id.is_a?(String) && ticket_id.present?)
        raise ArgumentError, "ticket must be a nonempty string or nil"
      end

      digest(
        [VERSION, "grant", actor_public_id, subject_public_id, capability, duration_seconds, reason_code,
         ticket_id,],
      )
    end

    def revoke(actor_public_id:, subject_public_id:, grant_public_id:, reason_code:)
      require_strings!(actor_public_id, subject_public_id, grant_public_id, reason_code)
      digest([VERSION, "revoke", actor_public_id, subject_public_id, grant_public_id, reason_code])
    end

    private

    def require_strings!(*values)
      return if values.all? { |value| value.is_a?(String) && value.present? }

      raise ArgumentError, "IAM operation identity fields must be nonempty strings"
    end

    def digest(parts)
      Digest::SHA256.hexdigest(JSON.generate(parts))
    end
  end
end
