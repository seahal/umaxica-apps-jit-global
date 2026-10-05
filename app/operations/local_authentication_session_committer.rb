# frozen_string_literal: true

# Serializes local result validation and the existing final issuance boundary in the same
# surface ticket transaction, using the established actor-before-ticket lock order.
class LocalAuthenticationSessionCommitter
  class << self
    public

    def call(controller:, flow:, actor:, nonce:, binding:)
      commit(
        controller: controller, flow: flow, actor: actor, nonce: nonce, binding: binding,
        pending_resume: false,
      )
    end

    def resume_pending!(controller:, flow:, actor:, nonce:)
      commit(
        controller: controller, flow: flow, actor: actor, nonce: nonce, binding: nil,
        pending_resume: true,
      )
    end

    private

    def commit(controller:, flow:, actor:, nonce:, binding:, pending_resume:)
      result =
        actor.class.connection_class_for_self.connected_to(role: :writing) do
          actor.with_lock do
            flow.class.connection_class_for_self.connected_to(role: :writing) do
              flow.class.transaction do
                flow.lock!
                now = flow.class.database_now
                validate_browser_binding!(
                  flow: flow, actor: actor, nonce: nonce, binding: binding,
                  pending_resume: pending_resume, now: now,
                )
                return { status: :already_finalized, token_id: flow.token_id } if flow.base_finalized_at

                commit_locked!(
                  controller: controller, flow: flow, actor: actor, binding: binding,
                  pending_resume: pending_resume, now: now,
                )
              end
            end
          end
        end
      if flow.is_a?(ClientSignInFlow) && flow.authentication_method == "secret"
        claim = ClientSecretCredential.find_by!(claim_sign_in_flow_ref: flow.public_id, client_id: actor.id)
        ClientSecretClaimFinalizer.call!(credential: claim, purge_after: ClientSecretLifetimesValue.purge_delay)
      end
      result
    end

    def validate_browser_binding!(flow:, actor:, nonce:, binding:, pending_resume:, now:)
      valid_delivery =
        if pending_resume
          flow.sign_in_session_limit_pending? && flow.result_digest.present? &&
            flow.result_generation.positive? && !flow.expired?(now)
        else
          flow.local_result_delivery_matches?(
            digest: binding.fetch(:digest),
            generation: binding.fetch(:generation), now: now,
          )
        end
      unless flow.nonce_matches?(nonce) && flow.principal_id == actor.id && valid_delivery
        raise BaseAuthAdmissionCoordinator::Denied, "local result binding mismatch"
      end
      return if flow.base_finalized_at || flow.sign_in_session_issuance_pending? || flow.sign_in_session_limit_pending?

      raise BaseAuthAdmissionCoordinator::Denied, "local result is not ready"
    end

    def commit_locked!(controller:, flow:, actor:, binding:, pending_resume:, now:)
      surface = LocalAuthenticationResultCoordinator.surface_for(flow)
      ceremony_model = BaseAuthAdmissionCoordinator::CEREMONY_SESSION.fetch(surface)
      ceremony =
        if pending_resume
          ceremony_model.lock.where(
            local_sign_in_flow_ref: flow.public_id,
            completed_at: nil, cancelled_at: nil, revoked_at: nil,
          ).sole
        else
          ceremony_model.lock.find(binding.fetch(:ceremony_session_ref))
        end
      unless ceremony.active?(now: now) && ceremony.admitted? &&
          %w(local_sign_in local_sign_up).include?(ceremony.admission_purpose) &&
          ceremony.local_sign_in_flow_ref == flow.public_id && ceremony.authentication_evidence_recorded? &&
          ceremony.authentication_method == flow.authentication_method
        raise BaseAuthAdmissionCoordinator::Denied, "local result ceremony mismatch"
      end

      result = controller.log_in(
        actor, establishment: :root_login, sign_in_flow: flow, require_totp_check: false,
               established_authentication_method: flow.authentication_method,
               authentication_event_at: flow.authentication_event_at,
               authentication_context: token_authentication_context(flow),
               audit_context: { auth_method: flow.authentication_method, flow: "local_authentication" },
      )
      case result.fetch(:status)
      when :success
        flow.reload.update!(base_finalized_at: now)
        ceremony.complete!(now: now)
      when :session_limit_pending
        flow.advance_sign_in_to_session_limit!(now: now) if flow.sign_in_session_issuance_pending?
      when :access_locked, :login_forbidden, :dpop_proof_invalid, :invalid_request
        flow.fail_sign_in!(now: now)
      else
        raise BaseAuthAdmissionCoordinator::Denied, "unexpected local finalization status"
      end
      result
    end

    def token_authentication_context(flow)
      case flow
      when OperatorSignInFlow
        unless AuthenticationContextValue::KEYS.include?(flow.authentication_context)
          raise BaseAuthAdmissionCoordinator::Denied, "operator authentication context missing"
        end

        flow.authentication_context
      when ClientSignInFlow, VisitorSignInFlow
        unless flow.authentication_context == AuthenticationContextValue::NORMAL_KEY
          raise BaseAuthAdmissionCoordinator::Denied, "authentication context is unavailable on this surface"
        end

        nil
      else
        raise BaseAuthAdmissionCoordinator::Denied, "unsupported local authentication flow"
      end
    end
  end
end
