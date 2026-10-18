# frozen_string_literal: true

class IdentityPasskeyNameCommitter
  class Denied < StandardError; end

  class << self
    public

    def call!(actor:, token:, passkey:, description:)
      policy = policy_for(actor, token, passkey)
      token.class.connection_class_for_self.connected_to(role: :writing) do
        token.class.transaction do
          actor.class.connection_class_for_self.connected_to(role: :writing) do
            actor.with_lock do
              device_session = token.device_session_record!
              device_session.with_lock do
                token.with_lock do
                  evidence = policy.management_credential(token: token)
                  raise Denied, "Passkey rename evidence is unavailable" unless evidence

                  evidence.lock!
                  passkey.lock!
                  unless policy.apply(:update?) && policy.management_authorized?(
                    token: token, now: token.class.database_now,
                  ) && active_passkey?(passkey)
                    raise Denied, "Passkey rename requires current scoped Step-Up"
                  end

                  passkey.update!(description: description)
                end
              end
            end
          end
        end
      end
      passkey
    end

    private

    def policy_for(actor, token, passkey)
      case [actor, token, passkey]
      in [Client, ClientToken, ClientPasskey] if token.user_id == actor.id && passkey.user_id == actor.id
        ClientPasskeyPolicy.new(passkey, user: actor)
      in [Visitor, VisitorToken, VisitorPasskey] if token.visitor_id == actor.id && passkey.visitor_id == actor.id
        VisitorPasskeyPolicy.new(passkey, user: actor)
      in [Operator, OperatorToken, OperatorPasskey] if token.staff_id == actor.id && passkey.staff_id == actor.id
        OperatorPasskeyPolicy.new(passkey, user: actor)
      else raise Denied, "Passkey rename binding mismatch"
      end
    end

    def active_passkey?(passkey)
      case passkey
      when ClientPasskey then passkey.status_id == ClientPasskeyStatus::ACTIVE && passkey.accessible?
      when VisitorPasskey then passkey.status_id == VisitorPasskeyStatus::ACTIVE && passkey.accessible?
      when OperatorPasskey then passkey.status_id == OperatorPasskeyStatus::ACTIVE
      else raise Denied, "unsupported passkey"
      end
    end
  end
end
