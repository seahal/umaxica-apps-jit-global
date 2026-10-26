# frozen_string_literal: true

class IdentityTotpNameCommitter
  class Denied < StandardError; end

  class InvalidTitle < ArgumentError; end

  class << self
    public

    def call!(actor:, token:, credential:, title:)
      validate_binding!(actor, token, credential, title)
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          Client.connection_class_for_self.connected_to(role: :writing) do
            actor.with_lock do
              raise Denied, "TOTP rename actor is unavailable" unless actor.login_allowed?

              device_session = token.device_session_record!
              device_session.with_lock do
                token.with_lock do
                  rename!(actor, token, credential, title)
                end
              end
            end
          end
        end
      end
    rescue TokenStatusManagement::StepUpEvidenceUnavailable => e
      raise Denied, e.message
    end

    private

    def validate_binding!(actor, token, credential, title)
      unless actor.is_a?(Client) && actor.persisted? && token.is_a?(ClientToken) && token.persisted? &&
          token.user_id == actor.id && credential.is_a?(ClientTotpCredential) && credential.persisted? &&
          credential.user_id == actor.id && (title.nil? || title.is_a?(String))
        raise Denied, "TOTP rename requires a bound app actor, session and credential"
      end
      raise InvalidTitle, "TOTP title must be 32 characters or fewer" if (title&.length || 0) > 32
    end

    def rename!(actor, token, credential, title)
      owned = ClientTotpCredential.lock.find_by(
        id: credential.id, public_id: credential.public_id, user_id: actor.id,
      )
      unless owned && ClientTotpCredentialPolicy.new(owned, user: actor).apply(:update?)
        raise Denied, "TOTP rename credential is unavailable"
      end

      now = ClientToken.database_now
      requirement = StepUpRequirement.new(
        scope: "settings_totp", step_up_required: true, allowed_methods: %i(passkey totp email_otp),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, purpose: "step_up", audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
        ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      )
      unless token.active_status?(now) &&
          StepUpResolver.call(token: token, requirement: requirement, now: now).satisfied?
        raise Denied, "TOTP rename requires current scoped Step-Up"
      end

      unless owned.title == title
        owned.update!(title: title)
        # D3 binds one consumption to this successful name update. Per-record target binding remains deferred.
        token.consume_step_up_evidence!(requirement:, now:)
      end
      owned
    end
  end
end
