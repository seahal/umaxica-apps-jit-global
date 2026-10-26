# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class CeremonyBindingsController < ::Auth::Org::ApplicationController
      include ::AuthCeremonySidCookie
      include ::AdmissionReferenceParameters

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open

      public

      def show
        apply_admission_transport_headers!
        return render_invalid_admission_request! if request.head?

        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "org", reference: entry_ref)
        if AuthAdmissionBinding::PARENT_PURPOSES.fetch(:authorization_transaction).include?(binding.purpose)
          return if enforce_sign_entry_sentry_for_binding!(binding)
        elsif AuthAdmissionBinding::PARENT_PURPOSES.fetch(:step_up_ceremony_transaction).include?(binding.purpose)
          intent = BaseAuthAdmissionCoordinator::HANDOFF_PURPOSE.key(binding.purpose)
          raise ArgumentError if intent.blank?

          BaseAuthAdmissionCoordinator.validate_admission_continuation!(
            binding:, surface: "org", expected_intent: intent,
          )
        else
          return render_invalid_admission_request!
        end

        attach_and_redirect!(binding, OperatorAuthCeremonySession)
      rescue BaseAuthAdmissionCoordinator::Denied, AuthAdmissionBinding::InvalidTransition,
             ActiveRecord::RecordNotFound, ArgumentError
        render_invalid_admission_request!
      end

      private

      def render_invalid_admission_request!
        render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request,
               content_type: "text/plain"
      end

      def apply_admission_transport_headers!
        response.headers["Cache-Control"] = "private, no-store"
        response.headers["Referrer-Policy"] = "no-referrer"
      end

      def attach_and_redirect!(binding, model)
        raw_sid =
          BaseAuthAdmissionCoordinator.with_admission_binding_lock!(binding) do |locked_binding|
            attach_current_auth_session!(locked_binding, model)
          end
        write_auth_ceremony_sid_cookie!(raw_sid) if raw_sid

        redirect_to(ceremony_binding_confirmation_url(binding), status: :see_other, allow_other_host: true)
      end

      def attach_current_auth_session!(binding, model)
        raw_sid = nil
        binding.with_lock do
          raise AuthAdmissionBinding::InvalidTransition, "binding is not live" unless binding.live?

          session_record = current_auth_session(model)
          unless binding.attached?
            if session_record.nil?
              now = model.database_now
              ttl = auth_ceremony_ttl_for_binding(binding, now, model)
              session_record, raw_sid = model.issue!(ttl:, now:)
            end
            binding.attach_auth_session!(auth_session: session_record, confirmation_ref: SecureRandom.uuid)
          end
          unless binding.auth_ceremony_session_id == session_record&.id
            raise BaseAuthAdmissionCoordinator::Denied.new(
              "Auth session does not match binding", code: "session_binding_mismatch",
            )
          end
        end
        raw_sid
      end

      def auth_ceremony_ttl_for_binding(binding, now, model)
        return model::DEFAULT_TTL unless binding.purpose == "authentication_handoff"

        remaining = binding.curfew_at - now
        raise BaseAuthAdmissionCoordinator::Denied.new(
          "sign-in path curfew has passed", code: "expired_admission",
        ) unless remaining.positive?

        [model::DEFAULT_TTL, remaining].min
      end

      def entry_ref
        raise ArgumentError if duplicate_admission_reference?("entry_ref")

        raise ArgumentError if BaseAuthAdmissionCoordinator.client_supplied_binding_proof?(params)

        value = params[:entry_ref]
        raise ArgumentError unless value.is_a?(String) && params[:transaction_ref].blank?

        value
      end

      def current_auth_session(model)
        raw_sid = read_auth_ceremony_sid_cookie
        return if raw_sid.blank?

        model.find_active_by_raw_sid(raw_sid)
      end

      def ceremony_binding_confirmation_url(binding)
        query = { binding_ref: binding.confirmation_ref, ri: params[:ri], lx: normalized_locale(params[:lx]) }.compact
        case binding.purpose
        when *AuthAdmissionBinding::PARENT_PURPOSES.fetch(:authorization_transaction)
          visa_org_ceremony_binding_confirmation_url(
            **query, host: visa_authority_host, protocol: "https",
          )
        when *AuthAdmissionBinding::PARENT_PURPOSES.fetch(:step_up_ceremony_transaction)
          base_org_ceremony_binding_confirmation_url(
            **query, host: base_rp_host, protocol: "https",
          )
        else
          raise ArgumentError, "unsupported ceremony binding purpose"
        end
      end
    end
  end
end
