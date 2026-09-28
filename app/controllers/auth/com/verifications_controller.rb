# typed: false
# frozen_string_literal: true

module Auth
  module Com
    class VerificationsController < Verification::BaseController
      include ::SurfaceInertiaPage
      include SignVerificationEntry

      AUTHENTICATION_MODE = :private

      private

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
          notice: flash[:notice].presence,
          cancel: step_up_cancellation_props,
        }
      end

      def verification_entry_methods
        return [] if @available_methods.blank?

        [
          [:passkey, "sign.app.verification.new.methods.passkey", :new_auth_com_verification_passkey_path],
          [:email_otp, "sign.app.verification.new.methods.email_otp", :new_auth_com_verification_email_path],
        ].filter_map do |method, label_key, path_helper|
          next unless @available_methods.include?(method)

          { key: method.to_s, label: t(label_key), href: public_send(path_helper, verification_method_params) }
        end
      end

      def verification_method_params
        @verification_method_params ||=
          begin
            scope = current_step_up_scope
            pt = current_step_up_pt_param
            attrs = { ri: params[:ri] }
            attrs[:scope] = scope if scope.present?
            attrs[:pt] = pt if pt.present?
            attrs
          end
      end

      def verification_success_notice_key
        "sign.app.verification.success.complete"
      end

      def verification_invalid_request_redirect_path(ri:)
        auth_com_settings_path(ri: ri)
      end
    end
  end
end
