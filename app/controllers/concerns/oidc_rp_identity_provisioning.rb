# typed: false
# frozen_string_literal: true

module OidcRpIdentityProvisioning
  extend ActiveSupport::Concern

  class_methods do
    def provisions_oidc_rp_identity(actor_class:, identity_class:, bridge_class: nil)
      self.oidc_rp_actor_class_name = actor_class.to_s
      self.oidc_rp_identity_class_name = identity_class.to_s
      self.oidc_rp_bridge_class_name = bridge_class&.to_s
    end
  end

  private

  def provision_rp_account_from_id_token_payload!(payload, canonical_audience)
    claims = rp_identity_claims(payload, expected_audience: canonical_audience)
    actor = actor_from_existing_identity(claims) || actor_from_public_subject_claim(claims)

    ensure_rp_identity_for(actor, claims)
    ensure_rp_bridge_for(actor)

    actor
  end

  def rp_identity_claims(payload, expected_audience:)
    audience = payload.fetch("aud")
    raise ArgumentError, "invalid audience type" unless audience.is_a?(Array)
    raise ArgumentError, "invalid audience size" unless audience.size == 1
    raise ArgumentError, "invalid audience value" unless audience.first.to_s == expected_audience.to_s

    {
      issuer: payload.fetch("iss").to_s,
      subject: payload.fetch("sub").to_s,
      audience: expected_audience.to_s,
    }
  end

  def actor_from_existing_identity(claims)
    identity =
      record_context_for(rp_identity_class).connected_to(role: :reading) do
        rp_identity_class.find_by(claims)
      end
    return unless identity

    find_rp_actor(identity.source_record_id)
  end

  def actor_from_public_subject_claim(claims)
    public_id = OidcSubject.public_id_from(
      claims.fetch(:subject),
      resource_type: rp_actor_resource_type,
    )
    raise ActiveRecord::RecordNotFound, "OIDC subject is not a valid RP subject" if public_id.blank?

    find_rp_actor_by_public_id(public_id)
  end

  def ensure_rp_identity_for(actor, claims)
    record_context_for(rp_identity_class).connected_to(role: :writing) do
      existing = rp_identity_class.find_by(claims)
      return existing if existing

      existing = rp_identity_class.find_by(source_record_id: actor.id)
      return existing if existing

      rp_identity_class.create!(
        **claims,
        source_record_id: actor.id,
        status_id: rp_identity_active_status_id,
      )
    end
  rescue ActiveRecord::RecordNotUnique
    record_context_for(rp_identity_class).connected_to(role: :writing) do
      rp_identity_class.find_by!(claims)
    end
  end

  def ensure_rp_bridge_for(actor)
    bridge_class = rp_bridge_class
    return unless bridge_class

    record_context_for(bridge_class).connected_to(role: :writing) do
      bridge = bridge_class.find_or_create_by!(bridge_class.core_actor_foreign_key => actor.id)
      bridge.update!(
        rp_client_id: bridge_class.core_default_client_id,
        audience: bridge_class.core_default_audience,
        host: bridge_class.core_default_host,
      ) unless bridge.core?
      bridge
    end
  end

  def rp_actor_class
    self.class.oidc_rp_actor_class_name.constantize
  end

  def rp_identity_class
    self.class.oidc_rp_identity_class_name.constantize
  end

  def rp_bridge_class
    self.class.oidc_rp_bridge_class_name&.constantize
  end

  def rp_identity_active_status_id
    identity_state_class = rp_identity_class.reflect_on_association(:identity_state)&.klass
    return identity_state_class::ACTIVE if identity_state_class&.const_defined?(:ACTIVE, false)

    1
  end

  def find_rp_actor(id)
    record_context_for(rp_actor_class).connected_to(role: :reading) do
      rp_actor_class.find(id)
    end
  end

  def find_rp_actor_by_public_id(public_id)
    record_context_for(rp_actor_class).connected_to(role: :reading) do
      rp_actor_class.find_by!(public_id: public_id)
    end
  end

  def rp_actor_resource_type
    case rp_actor_class.name
    when "Operator" then "operator"
    when "Visitor" then "visitor"
    else "client"
    end
  end

  def record_context_for(model_class)
    model_class.connection_class_for_self
  end
end
