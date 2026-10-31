# frozen_string_literal: true

class IdentityEmailPreferenceCommitter
  class Denied < StandardError; end

  class DependencyFailure < StandardError; end

  PREFERENCE_KEYS = %w(notifiable promotional).freeze

  class << self
    public

    def call!(actor:, token:, email:, preferences:)
      validate_binding!(actor, token, email)
      attributes = normalize_preferences!(preferences)
      Client.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          raise Denied, "Email preference actor is unavailable" unless actor.login_allowed?

          owned = ClientEmail.lock.find_by(id: email.id, public_id: email.public_id, user_id: actor.id)
          unless owned && ClientEmailPolicy.new(owned, user: actor).apply(:update?)
            raise Denied, "Email preference record is unavailable"
          end

          attributes = {} if owned.subscription_preferences_locked?
          owned.assign_attributes(attributes)
          changed = owned.has_changes_to_save?
          raise ActiveRecord::RecordInvalid, owned if changed && !owned.valid?

          OpBaseAppRecord.connected_to(role: :writing) do
            ClientToken.transaction do
              device_session = token.device_session_record!
              device_session.with_lock do
                unless device_session.usable? && device_session.user_id == actor.id
                  raise Denied, "Email preference device session is unavailable"
                end

                token.with_lock do
                  unless token.device_session_id == device_session.id &&
                      device_session.current_refresh_token_id == token.id
                    raise Denied, "Email preference session binding changed"
                  end

                  authorize_and_consume!(actor, token, email: owned, changed: changed)
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
      raise DependencyFailure, "Email preference storage is unavailable: #{e.class}"
    end

    private

    def validate_binding!(actor, token, email)
      unless actor.is_a?(Client) && actor.persisted? && token.is_a?(ClientToken) && token.persisted? &&
          token.user_id == actor.id && email.is_a?(ClientEmail) && email.persisted? && email.user_id == actor.id
        raise Denied, "Email preference update requires a bound app actor, session and email"
      end
    end

    def normalize_preferences!(preferences)
      unless preferences.is_a?(Hash)
        raise ArgumentError, "Email preferences must be a strong-parameter hash"
      end

      attributes = preferences.stringify_keys
      raise ArgumentError, "Unsupported email preference" unless (attributes.keys - PREFERENCE_KEYS).empty?

      attributes
    end

    def authorize_and_consume!(actor, token, email:, changed:)
      now = ClientToken.database_now
      requirement = StepUpRequirement.new(
        scope: "settings_email", step_up_required: true, allowed_methods: %i(email_otp passkey totp),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, purpose: "step_up", audience: "step_up:app",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
        ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: actor.public_id, resource_ref: email.public_id, tenant_ref: nil,
      )
      unless token.active_status?(now) &&
          StepUpResolver.call(token: token, requirement: requirement, now: now).satisfied?
        raise Denied, "Email preference update requires current scoped Step-Up"
      end

      token.consume_step_up_evidence!(requirement:, now:) if changed
    end
  end
end
