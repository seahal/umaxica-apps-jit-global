# frozen_string_literal: true

# Local login results use the same opaque transport as OIDC, but their durable authority is the
# actor-specific sign-in flow. An OIDC authorization transaction is never synthesized for Base.
class LocalAuthenticationResultCoordinator
  RESULT_PURPOSE = "local_sign_in_result"
  Issuance = Data.define(:code, :reference)

  class << self
    public

    def issue!(flow:, ceremony_session_ref:, store: Valkey::AuthState::OpaqueAdmissionStore.new)
      surface = surface_for(flow)
      code = SecureRandom.urlsafe_base64(Valkey::AuthState::OpaqueAdmissionStore::CODE_BYTES, padding: false)
      digest = Valkey::AuthState::OpaqueAdmissionStore.digest_for(purpose: RESULT_PURPOSE, raw_code: code)
      generation = flow.prepare_local_result_delivery!(
        digest: digest, ttl: Valkey::AuthState::OpaqueAdmissionStore::CODE_TTL,
      )
      reference = SecureRandom.uuid
      store.issue!(
        purpose: RESULT_PURPOSE, actor_type: BaseAuthAdmissionCoordinator::SURFACE_ACTOR.fetch(surface),
        surface: surface, subject_ref: flow.public_id, ceremony_session_ref: ceremony_session_ref,
        result_generation: generation, raw_code: code, reference: reference,
      )
      Issuance.new(code:, reference:)
    end

    def read_reference!(flow:, surface:, reference:, store: Valkey::AuthState::OpaqueAdmissionStore.new)
      unless surface_for(flow) == surface.to_s
        raise BaseAuthAdmissionCoordinator::Denied, "local result surface mismatch"
      end
      raise BaseAuthAdmissionCoordinator::Denied, "local result missing" unless
        reference.is_a?(String) && reference.present?

      payload = store.read_reference!(reference:, purposes: [RESULT_PURPOSE])
      raise BaseAuthAdmissionCoordinator::Denied, "local result missing" unless payload
      unless payload.fetch("surface") == surface.to_s && payload.fetch("subject_ref") == flow.public_id &&
          payload.fetch("actor_type") == BaseAuthAdmissionCoordinator::SURFACE_ACTOR.fetch(surface.to_s)
        raise BaseAuthAdmissionCoordinator::Denied, "local result binding mismatch"
      end

      generation = Integer(payload.fetch("result_generation").to_s, 10)
      unless flow.local_result_delivery_matches?(digest: flow.result_digest, generation: generation)
        raise BaseAuthAdmissionCoordinator::Denied, "local result generation mismatch"
      end

      { digest: flow.result_digest, generation:, ceremony_session_ref: payload.fetch("ceremony_session_ref") }
    rescue KeyError, ArgumentError
      raise BaseAuthAdmissionCoordinator::Denied, "local result rejected"
    end

    def surface_for(flow)
      case flow
      when ClientSignInFlow then "app"
      when VisitorSignInFlow then "com"
      when OperatorSignInFlow then "org"
      else raise ArgumentError, "unsupported local login flow"
      end
    end
  end
end
