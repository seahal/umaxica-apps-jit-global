# typed: false
# frozen_string_literal: true

module Auth
  module App
    class CeremonyBindingsController < ::Auth::App::ApplicationController
      include ::AuthCeremonySidCookie

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open

      public

      def create
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_ref)
        model = ClientAuthCeremonySession
        session_record = current_unadmitted_session(model)
        unless binding.attached?
          session_record, raw_sid = model.issue! if session_record.nil?
          write_auth_ceremony_sid_cookie!(raw_sid) if raw_sid
          binding.attach_auth_session!(auth_session: session_record, confirmation_ref: SecureRandom.uuid)
        end
        unless binding.auth_ceremony_session_id == session_record&.id
          raise BaseAuthAdmissionCoordinator::Denied.new(
            "Auth session does not match binding",
            code: "session_binding_mismatch",
          )
        end

        redirect_to(
          base_app_ceremony_binding_confirmation_url(
            binding_ref: binding.confirmation_ref, ri: params[:ri], host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), protocol: "https",
          ), status: :see_other, allow_other_host: true,
        )
      rescue BaseAuthAdmissionCoordinator::Denied, AuthAdmissionBinding::InvalidTransition,
             ActiveRecord::RecordNotFound, ArgumentError
        render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request,
               content_type: "text/plain"
      end

      private

      def entry_ref
        value = params[:entry_ref]
        raise ArgumentError unless value.is_a?(String) && params[:transaction_ref].blank?

        value
      end

      def current_unadmitted_session(model)
        raw_sid = read_auth_ceremony_sid_cookie
        return if raw_sid.blank?

        record = model.find_active_by_raw_sid(raw_sid)
        return if record.nil? || record.admitted?

        record
      end
    end
  end
end
