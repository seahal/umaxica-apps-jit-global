# frozen_string_literal: true

class IdentityTotpNameCommitter
  class Denied < StandardError; end

  class DependencyFailure < StandardError; end

  class InvalidTitle < ArgumentError; end

  class << self
    public

    def call!(actor:, token:, credential:, title:)
      validate_binding!(actor, token, credential, title)
      Client.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          raise Denied, "TOTP rename actor is unavailable" unless actor.login_allowed?

          owned = ClientTotpCredential.lock.find_by(
            id: credential.id, public_id: credential.public_id, user_id: actor.id,
          )
          unless owned && ClientTotpCredentialPolicy.new(owned, user: actor).apply(:update?)
            raise Denied, "TOTP rename credential is unavailable"
          end

          owned.assign_attributes(title: title)
          changed = owned.has_changes_to_save?
          raise ActiveRecord::RecordInvalid, owned if changed && !owned.valid?

          OpBaseAppRecord.connected_to(role: :writing) do
            if OpBaseAppRecord.lease_connection.transaction_open?
              raise DependencyFailure, "TOTP rename requires an independent OP commit"
            end

            ClientToken.transaction do
              device_session = token.device_session_record!
              device_session.with_lock do
                unless device_session.usable? && device_session.user_id == actor.id
                  raise Denied, "TOTP name device session is unavailable"
                end

                token.with_lock do
                  unless token.device_session_id == device_session.id &&
                      device_session.current_refresh_token_id == token.id
                    raise Denied, "TOTP name session binding changed"
                  end

                  authorize_and_consume!(actor, token, credential: owned, changed: changed)
                end
              end
            end
          end

          owned.save! if changed
          owned
        end
      end
    rescue TokenStatusManagement::StepUpEvidenceUnavailable => e
      raise Denied, e.message
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
      raise DependencyFailure, "TOTP name storage is unavailable: #{e.class}"
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

    def authorize_and_consume!(actor, token, credential:, changed:)
      now = ClientToken.database_now
      requirement = StepUpRequirement.new(
        scope: "settings_totp", step_up_required: true, allowed_methods: %i(passkey totp email_otp),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, purpose: "step_up", audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
        ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: actor.public_id, resource_ref: credential.public_id,
        tenant_ref: nil,
      )
      unless token.active_status?(now) &&
          StepUpResolver.call(token: token, requirement: requirement, now: now).satisfied?
        raise Denied, "TOTP rename requires current scoped Step-Up"
      end

      token.consume_step_up_evidence!(requirement:, now:) if changed
    end
  end
end
