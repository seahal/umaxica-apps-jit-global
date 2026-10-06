# typed: false
# frozen_string_literal: true

module OidcRpIdentityProvisioning
  extend ActiveSupport::Concern

  class_methods do
    def provisions_oidc_rp_identity(actor_class:, identity_class:, binding_class:, bridge_class: nil)
      self.oidc_rp_actor_class = actor_class
      self.oidc_rp_identity_class = identity_class
      self.oidc_rp_binding_class = binding_class
      self.oidc_rp_bridge_class = bridge_class
    end
  end

  private

  def verified_access_token_resource_for_callback(token_response)
    access_token = token_response[:access_token] || token_response["access_token"]
    result = OidcAccessTokenAuthenticator.call(
      access_token: access_token,
      resource_type: rp_actor_resource_type,
      host: oidc_base_authority_host,
      authorization_scheme: "Bearer",
    )
    return result.resource if result.success? && access_token_client_id(result) == oidc_client_id

    raise ActiveRecord::RecordNotFound, "OIDC access token is not authoritative for this RP"
  end

  def verified_userinfo_claims_for_callback(token_response)
    userinfo_url = OidcIssuer.userinfo_endpoint(rp_actor_resource_type)
    ::OidcRpUserInfoClient.call(
      access_token: token_response[:access_token] || token_response["access_token"],
      userinfo_url: userinfo_url,
      require_https: oidc_userinfo_endpoint_requires_https?(userinfo_url),
    )
  end

  def provision_rp_account_from_id_token_payload!(payload, canonical_audience, authoritative_resource: nil)
    claims = rp_identity_claims(payload, expected_audience: canonical_audience)
    binding = find_exact_binding(claims)
    actor =
      if binding
        actor_from_binding(binding)
      else
        actor_from_authoritative_resource!(authoritative_resource, claims)
      end

    verify_binding_resource!(actor, authoritative_resource, claims)

    ensure_rp_identity_binding_for(actor, claims) unless binding
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

  def access_token_client_id(result)
    AuthorizationTokenClaims.client_id(result.payload).to_s
  end

  def find_exact_binding(claims)
    record_context_for(rp_binding_class).connected_to(role: :reading) do
      rp_binding_class.find_by(claims)
    end
  end

  def actor_from_binding(binding)
    identity =
      case binding
      when ClientOidcIdentityBinding then binding.client_identity
      when VisitorOidcIdentityBinding then binding.visitor_identity
      when OperatorOidcIdentityBinding then binding.operator_identity
      else
        raise ActiveRecord::RecordNotFound, "OIDC identity binding class is not registered"
      end

    find_rp_actor(identity.source_record_id)
  end

  def actor_from_authoritative_resource!(resource, claims)
    raise ActiveRecord::RecordNotFound, "OIDC identity binding requires an authoritative resource" unless resource
    unless resource.is_a?(rp_actor_class)
      raise ActiveRecord::RecordNotFound, "OIDC authoritative resource type does not match the RP"
    end

    expected_subject = OidcSubject.for(resource, resource_type: rp_actor_resource_type)
    return resource if expected_subject == claims.fetch(:subject)

    raise ActiveRecord::RecordNotFound, "OIDC subject does not match the authoritative resource"
  end

  def verify_binding_resource!(actor, authoritative_resource, claims)
    return unless authoritative_resource
    unless authoritative_resource.is_a?(rp_actor_class)
      raise ActiveRecord::RecordNotFound, "OIDC authoritative resource type does not match the RP"
    end

    expected_subject = OidcSubject.for(authoritative_resource, resource_type: rp_actor_resource_type)
    return if actor.id == authoritative_resource.id && expected_subject == claims.fetch(:subject)

    raise ActiveRecord::RecordNotFound, "OIDC identity binding mismatch"
  end

  def ensure_rp_identity_binding_for(actor, claims)
    identity =
      record_context_for(rp_identity_class).connected_to(role: :reading) do
        rp_identity_class.find_by!(source_record_id: actor.id)
      end

    expected_subject = OidcSubject.for(actor, resource_type: rp_actor_resource_type)
    unless expected_subject == claims.fetch(:subject)
      raise ActiveRecord::RecordNotFound, "OIDC subject does not match the canonical actor"
    end

    record_context_for(rp_identity_class).connected_to(role: :writing) do
      rp_binding_class.create!(**binding_attributes(identity, claims))
    end
  rescue ActiveRecord::RecordNotUnique
    record_context_for(rp_identity_class).connected_to(role: :writing) do
      binding = rp_binding_class.find_by!(claims)
      verify_binding_resource!(actor_from_binding(binding), actor, claims)
    end
  end

  def binding_attributes(identity, claims)
    return { client_identity: identity, **claims } if rp_binding_class == ClientOidcIdentityBinding
    return { visitor_identity: identity, **claims } if rp_binding_class == VisitorOidcIdentityBinding
    return { operator_identity: identity, **claims } if rp_binding_class == OperatorOidcIdentityBinding

    raise ActiveRecord::RecordNotFound, "OIDC identity binding class is not registered"
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
    self.class.oidc_rp_actor_class
  end

  def rp_identity_class
    self.class.oidc_rp_identity_class
  end

  def rp_binding_class
    self.class.oidc_rp_binding_class
  end

  def rp_bridge_class
    self.class.oidc_rp_bridge_class
  end

  def find_rp_actor(id)
    record_context_for(rp_actor_class).connected_to(role: :reading) do
      rp_actor_class.find(id)
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
