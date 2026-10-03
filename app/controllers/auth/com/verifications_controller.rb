# typed: false
# frozen_string_literal: true

module Auth
  module Com
    class VerificationsController < ::Auth::Com::ApplicationController
      include ::SurfaceInertiaPage
      include AuthCeremonyAdmission
      include AuthStepUpCeremonyContext
      include AuthStepUpCeremonyEntry

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open

      private

      def ceremony_actor_model = Visitor

      def ceremony_step_up_session_model = VisitorStepUpSession

      def ceremony_session_token(session_record) = session_record.visitor_token

      def ceremony_token_owned_by?(token, actor) = token.visitor_id == actor.id

      def authorize_step_up_ceremony_actor!(actor)
        authorize!(actor, to: :show?, context: { user: actor })
      end

      def ceremony_supported_methods = %i(passkey email_otp)

      def auth_step_up_ceremony_clean_url = auth_com_verification_path(ri: params[:ri])

      def step_up_cancellation_props
        { label: t("actions.cancel"), action: auth_com_verification_cancellation_path(ri: params[:ri]), method: "post" }
      end

      # The entry screen lists only the step-up methods this actor may use. Guards, step-up session
      # handling and redirects stay in SignVerificationEntry; this surface only answers with an
      # Inertia component instead of an ERB template.
      def render_verification_entry_page
        render inertia: true, props: verification_entry_props
      end

      def verification_entry_props
        {
          title: t("sign.app.verification.index.title"),
          heading: t("sign.app.verification.index.title"),
          section_title: t("sign.app.verification.new.title"),
          description: t("sign.app.verification.new.description"),
          methods: verification_entry_methods,
          no_methods_notice: @available_methods.blank? ? t("views.sign.app.verifications.show.no_methods") : nil,
          notice: nil,
          cancel: step_up_cancellation_props,
        }
      end

      def verification_entry_methods
        [
          (
            if @available_methods.include?(:passkey)
              { key: "passkey",
                label: t("sign.app.verification.new.methods.passkey"),
                href: new_auth_com_verification_passkey_path(ri: params[:ri]), }
            end
          ),
          (
            if @available_methods.include?(:email_otp)
              { key: "email_otp",
                label: t("sign.app.verification.new.methods.email_otp"),
                href: new_auth_com_verification_email_path(ri: params[:ri]), }
            end
          ),
        ].compact
      end
    end
  end
end
