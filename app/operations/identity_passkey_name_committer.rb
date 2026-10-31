# frozen_string_literal: true

class IdentityPasskeyNameCommitter
  class Denied < StandardError; end

  class DependencyFailure < StandardError; end

  class << self
    public

    def call!(actor:, token:, passkey:, description:)
      policy_for(actor, token, passkey)
      case actor
      when Client
        AppZenithRecord.connected_to(role: :writing) do
          actor.with_lock do
            owned = ClientPasskey.lock.find_by!(id: passkey.id, user_id: actor.id, external_id: passkey.external_id)
            rename!(actor, token, owned, description, :app)
          end
        end
      when Operator
        OrgZenithRecord.connected_to(role: :writing) do
          actor.with_lock do
            owned = OperatorPasskey.lock.find_by!(id: passkey.id, staff_id: actor.id, external_id: passkey.external_id)
            rename!(actor, token, owned, description, :org)
          end
        end
      end
    rescue ActiveRecord::RecordNotFound, ActiveRecord::StaleObjectError => e
      raise Denied, e.message
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
      raise DependencyFailure, "Passkey name storage is unavailable: #{e.class}"
    end

    private

    def rename!(actor, token, passkey, description, surface)
      policy = policy_for(actor, token, passkey)
      passkey.assign_attributes(description: description)
      changed = passkey.has_changes_to_save?
      raise ActiveRecord::RecordInvalid, passkey if changed && !passkey.valid?

      case surface
      when :app
        OpBaseAppRecord.connected_to(role: :writing) do
          if OpBaseAppRecord.lease_connection.transaction_open?
            raise DependencyFailure, "Passkey rename requires an independent OP transaction"
          end

          ClientToken.transaction { authorize_and_consume!(actor, token, passkey, policy, changed) }
        end
      when :org
        OpBaseOrgRecord.connected_to(role: :writing) do
          if OpBaseOrgRecord.lease_connection.transaction_open?
            raise DependencyFailure, "Passkey rename requires an independent OP transaction"
          end

          OperatorToken.transaction { authorize_and_consume!(actor, token, passkey, policy, changed) }
        end
      else
        raise Denied, "unsupported passkey surface"
      end
      return passkey unless changed

      passkey.save!
      occurred_at = (surface == :app) ? Client.database_now : Operator.database_now
      PasskeyAuditOutbox.record_for!(
        passkey: passkey, event_type: "passkey.description_changed", surface: surface.to_s,
        actor_ref: actor.public_id, operation_ref: SecureRandom.uuid, occurred_at: occurred_at,
      )
      passkey
    end

    def authorize_and_consume!(_actor, token, passkey, policy, changed)
      device = token.device_session_record!
      device.with_lock do
        token.with_lock do
          evidence = policy.management_credential(token: token)
          raise Denied, "Passkey rename evidence is unavailable" unless evidence

          evidence.lock!
          now = token.is_a?(ClientToken) ? ClientToken.database_now : OperatorToken.database_now
          unless token.device_session_id == device.id && policy.apply(:update?) &&
              policy.management_authorized?(token: token, now: now) && active_passkey?(passkey)
            raise Denied, "Passkey rename requires current scoped Step-Up"
          end

          token.consume_step_up_evidence!(requirement: policy.management_requirement(token: token)) if changed
        end
      end
    rescue TokenStatusManagement::StepUpEvidenceUnavailable => e
      raise Denied, e.message
    end

    def policy_for(actor, token, passkey)
      case [actor, token, passkey]
      in [Client, ClientToken, ClientPasskey] if token.user_id == actor.id && passkey.user_id == actor.id
        ClientPasskeyPolicy.new(passkey, user: actor)
      in [Operator, OperatorToken, OperatorPasskey] if token.staff_id == actor.id && passkey.staff_id == actor.id
        OperatorPasskeyPolicy.new(passkey, user: actor)
      else raise Denied, "Passkey rename binding mismatch"
      end
    end

    def active_passkey?(passkey)
      case passkey
      when ClientPasskey then passkey.status_id == ClientPasskeyStatus::ACTIVE && passkey.accessible?
      when OperatorPasskey then passkey.status_id == OperatorPasskeyStatus::ACTIVE
      else raise Denied, "unsupported passkey"
      end
    end
  end
end
