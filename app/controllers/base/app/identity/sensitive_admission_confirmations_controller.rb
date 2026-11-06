# frozen_string_literal: true

module Base
  module App
    module Identity
      # The original Base RP browser confirms an Auth-attached O-9 admission before Auth can write.
      class SensitiveAdmissionConfirmationsController < ::Base::App::ApplicationController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        public

        def show
          authorize!(current_client, to: :show?)
          apply_base_browser_continuation_headers!
          validate_confirmation_context!
          render "base/shared/ceremony_binding_confirmation", layout: false,
                                                              locals: { lx: normalized_locale(params[:lx]) }
        rescue BaseAuthAdmissionCoordinator::Denied, ArgumentError
          render_invalid_confirmation!
        end

        def create
          authorize!(current_client, to: :show?)
          apply_base_browser_continuation_headers!
          session_record = validate_confirmation_context!
          access_token = BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE)
          digest = AuthAdmissionBinding.browser_digest(
            surface: "app", entry_ref: session_record.public_id, nonce: require_base_admission_browser_nonce!,
          )
          result = VisaSensitiveAdmissionClient.new(surface: "app", access_token:).confirm_browser!(
            admission_ref: admission_ref,
            rp_session_ref: session_record.public_id,
            browser_binding_digest: digest,
          )
          return head :service_unavailable if result.status == :dependency
          return head :unauthorized if result.status == :unauthorized
          return render_invalid_confirmation! unless result.ok?

          redirect_to(
            auth_app_ceremony_bindings_url(
              entry_ref: entry_ref, host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), protocol: "https",
            ),
            status: :see_other,
            allow_other_host: true,
          )
        rescue BaseAuthAdmissionCoordinator::Denied, ArgumentError
          render_invalid_confirmation!
        end

        private

        def validate_confirmation_context!
          return invalid_confirmation! unless admission_ref.match?(ClientVisaSensitiveAdmission::PUBLIC_REF_PATTERN)
          return invalid_confirmation! unless entry_ref.match?(AuthAdmissionBinding::REFERENCE_PATTERN)

          state = browser_rp_access_state
          session_record = state.rp_session
          actor = BaseZenithIdentityResolver.call(access_state: state, surface: :app) if state.status == :valid
          unless actor == current_client &&
              session_record.is_a?(RpBaseAppSession) && session_record.active? &&
              session_record.absolute_expires_at > RpBaseAppRecord.database_now
            invalid_confirmation!
          end
          require_base_admission_browser_nonce!
          session_record
        end

        def admission_ref
          value = params[:admission_ref]
          raise ArgumentError unless value.is_a?(String)

          value
        end

        def entry_ref
          value = params[:entry_ref]
          raise ArgumentError unless value.is_a?(String)

          value
        end

        def invalid_confirmation!
          raise BaseAuthAdmissionCoordinator::Denied.new(
            "sensitive admission confirmation is unavailable", code: "invalid_admission",
          )
        end

        def render_invalid_confirmation!
          render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request,
                 content_type: "text/plain"
        end
      end
    end
  end
end
