# frozen_string_literal: true

class IdentityEmailPreferenceCommitter
  # An enclosing OP transaction would defer the evidence consumption while the independent
  # Zenith preference write commits. Refuse instead of reporting a committed preference.
  class TransactionConflict < ArgumentError; end

  class Denied < StandardError; end

  class DependencyFailure < StandardError; end

  PREFERENCE_KEYS = %w(notifiable promotional).freeze

  class << self
    public

    def call!(actor:, token:, email:, preferences:, step_up_evidence: nil)
      validate_binding!(actor, token, email)
      require_independent_ticket_commit!
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

                  authorize_step_up!(actor, token, evidence: step_up_evidence)
                end
              end
            end
          end

          owned.save! if changed
          ClientContactAuditOutbox.record_preferences_changed!(actor:, email: owned) if changed
          owned
        end
      end
    rescue TokenStatusManagement::StepUpEvidenceUnavailable => e
      raise Denied, e.message
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
      raise DependencyFailure, "Email preference storage is unavailable: #{e.class}"
    end

    private

    # Evidence verification precedes the Zenith preference write, so it must own its commit.
    # Checked before any lock or evidence consumption.
    def require_independent_ticket_commit!
      OpBaseAppRecord.connected_to(role: :writing) do
        connection = OpBaseAppRecord.lease_connection
        if connection.transaction_open?
          raise TransactionConflict, "Email preference update requires an independent OP commit"
        end
      end
    end

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

    def authorize_step_up!(actor, token, evidence:)
      return if StepUpEvidenceVerifier.call(evidence:, actor:, token:)

      raise TokenStatusManagement::StepUpEvidenceUnavailable, "Email preference update requires current Step-Up"
    end
  end
end
