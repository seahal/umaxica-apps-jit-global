# frozen_string_literal: true

class SocialAuditDeliveryJob < ApplicationJob
  queue_as :retention

  public

  def perform(batch_size: 500)
    unless batch_size.is_a?(Integer) && batch_size.between?(1, 500)
      raise ArgumentError, "Social audit delivery requires a bounded batch"
    end

    AppZenithRecord.connected_to(role: :writing) do
      ClientSocialAuditOutbox.where(acknowledged_at: nil).order(:id).limit(batch_size).each do |event|
        event.with_lock do
          next if event.acknowledged_at

          owner = Client.find_by!(public_id: event.owner_ref)
          audit = persist_chronicle!(event, owner)
          unless identity_matches?(audit, event, owner)
            raise ArgumentError, "Social Chronicle event identity conflicts with its Source"
          end

          event.update!(acknowledged_at: ClientSocialAuditOutbox.database_now)
        end
      end
    end
  end

  private

  def event_id_for(event)
    case event.event_name
    when "linked" then ClientChronicleEvent::SOCIAL_LINKED
    when "unlinked" then ClientChronicleEvent::SOCIAL_UNLINKED
    else raise ArgumentError, "Unsupported social audit event: #{event.event_name.inspect}"
    end
  end

  def context_for(event)
    { "auth_method" => "social",
      "provider" => event.provider,
      "social_identity_type" => "ClientExternalIdentity", }
  end

  def identity_matches?(audit, event, owner)
    audit.event_uuid == event.event_uuid && audit.event_id == event_id_for(event) &&
      audit.level_id == ClientChronicleLevel::NOTHING && audit.actor_type == "Client" &&
      audit.actor_id == owner.id && audit.subject_type == "Client" &&
      audit.subject_id.to_s == owner.id.to_s && audit.occurred_at == event.occurred_at &&
      audit.context == context_for(event)
  end

  def persist_chronicle!(event, owner)
    ChronicleRecord.connected_to(role: :writing) do
      prior = ClientChronicle.find_by(event_uuid: event.event_uuid)
      return prior if prior

      ClientChronicleEvent.find(event_id_for(event))
      ClientChronicleLevel.find(ClientChronicleLevel::NOTHING)
      ClientChronicle.create!(
        event_uuid: event.event_uuid, actor_type: "Client", actor_id: owner.id,
        event_id: event_id_for(event), level_id: ClientChronicleLevel::NOTHING,
        subject_id: owner.id.to_s, subject_type: "Client", occurred_at: event.occurred_at,
        context: context_for(event),
      )
    end
  rescue ActiveRecord::RecordNotUnique
    ChronicleRecord.connected_to(role: :writing) { ClientChronicle.find_by!(event_uuid: event.event_uuid) }
  end
end
