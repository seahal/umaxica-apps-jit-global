# frozen_string_literal: true

# The caller owns authorization and the Source mutation transaction.
class ContactBindingAuditRecorder
  class << self
    public

    def call!(actor_context:, actor:, contact:, operation_ref:, event_name:)
      model, kind, owner_id = source_for(contact)
      validate_actor_context!(model, owner_id, actor, contact, actor_context)
      fact_matches = (event_name == "finalized" && contact.binding_effective?) ||
        (event_name == "released" && contact.binding_released?)
      raise ArgumentError, "Contact audit does not match its committed binding fact" unless fact_matches

      model.record!(
        contact_kind: kind, event_name: event_name, owner_ref: actor.public_id,
        contact_ref: contact.public_id, operation_ref: operation_ref,
        actor_ref: actor_context.authenticated? ? actor_context.subject.public_id : nil,
      )
    end

    private

    def source_for(contact)
      case contact
      when ClientEmail then [ClientContactAuditOutbox, "email", contact.user_id]
      when ClientTelephone then [ClientContactAuditOutbox, "telephone", contact.user_id]
      when VisitorEmail then [VisitorContactAuditOutbox, "email", contact.visitor_id]
      when VisitorTelephone then [VisitorContactAuditOutbox, "telephone", contact.visitor_id]
      else raise ArgumentError, "unsupported Contact audit subject"
      end
    end

    def validate_actor_context!(model, owner_id, actor, contact, actor_context)
      expected_actor = (model == ClientContactAuditOutbox) ? Client : Visitor
      unless actor.is_a?(expected_actor) && actor.persisted? && contact.persisted? && owner_id == actor.id
        raise ArgumentError, "Contact audit owner mismatch"
      end

      expected_tld = (model == ClientContactAuditOutbox) ? :app : :com
      expected_role = (model == ClientContactAuditOutbox) ? :client : :visitor
      valid_context = actor_context.is_a?(ActorValuesContext) && actor_context.tld == expected_tld &&
        ((actor_context.actor_type == expected_role && actor_context.subject == actor) ||
         (actor_context.unauthenticated? && actor_context.subject.equal?(Unauthenticated.instance)))
      raise ArgumentError, "actor context does not match Contact audit owner" unless valid_context

    end
  end
end
