# typed: false
# frozen_string_literal: true

module Base
  module App
    class VerificationsController < Base::App::ApplicationController
      include BaseStepUpIntent
      include SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      public

      def show
        authorize!(current_client, to: :show?)
        render_step_up_start!(
          actor: current_client, token: current_session_token, allowed_scopes: StepUpScopeCatalog::APP,
          title: t("sign.app.verification.new.title"),
          description: t("sign.app.verification.new.description"),
          action: base_app_verification_path(ri: params[:ri]),
          cancel: base_app_identity_path(ri: params[:ri]),
        )
      end

      def create
        authorize!(current_client, to: :show?)
        # An actor without an authenticator chooses one on Base first; nothing is issued here.
        return redirect_to_bootstrap_choice if available_step_up_methods(current_client).blank?

        redirect_to_step_up_ceremony!(
          actor: current_client, token: current_session_token, allowed_scopes: StepUpScopeCatalog::APP,
          sign_url_builder: ->(**query) {
            auth_app_verification_url(query.merge(host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), protocol: "https"))
          },
          setup_url_builder: ->(**query) {
            new_auth_app_verification_setup_url(
              query.merge(host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), protocol: "https"),
            )
          },
        )
      end

      private

      def step_up_requirement(scope:, **options)
        if scope == "settings_email"
          return_to = resolve_step_up_pt(params[:pt])
          path = URI.parse(return_to).path if return_to.present?
          match = %r{\A/identity/emails/([A-Za-z0-9_-]{21})/edit\z}.match(path.to_s)
          if match
            email = ClientEmail.find_by!(user_id: current_client.id, public_id: match[1])
            return super(scope: scope, **options.merge(resource_ref: email.public_id))
          end
        end

        if scope == "settings_totp"
          return_to = resolve_step_up_pt(params[:pt])
          path = URI.parse(return_to).path if return_to.present?
          match = %r{\A/identity/totps/([A-Za-z0-9_-]{21})\z}.match(path.to_s)
          if match
            credential = current_client.client_totp_credentials.find_by!(public_id: match[1])
            return super(scope: scope, **options.merge(resource_ref: credential.public_id))
          end
        end

        target = additional_step_up_target(scope)
        return super(scope: scope, **options.merge(resource_ref: target)) if target

        super
      end

      def additional_step_up_target(scope)
        return unless %w(settings_passkey settings_secret_credential settings_telephone).include?(scope)

        return_to = resolve_step_up_pt(params[:pt])
        path = URI.parse(return_to).path if return_to.present?
        issuance_match = %r{\A/secret_issuances/([A-Za-z0-9_-]{21})\z}.match(path.to_s)
        if issuance_match && %w(settings_passkey settings_secret_credential).include?(scope)
          issuance = ClientSecretIssuance.find_by!(
            public_id: issuance_match[1], client_id: current_client.id,
            browser_session_ref: current_session_token.public_id, sign_up_flow_ref: nil,
          )
          expected_scope = (issuance.origin == "manual") ? "settings_secret_credential" : "settings_passkey"
          raise ActionController::BadRequest, "Secret issuance scope mismatch" unless scope == expected_scope

          return issuance.public_id
        end
        case scope
        when "settings_passkey"
          match = %r{\A/identity/passkeys/([A-Za-z0-9_-]{21})\z}.match(path.to_s)
          return current_client.client_passkeys.active.find_by!(public_id: match[1]).public_id if match
        when "settings_secret_credential"
          match = %r{\A/secrets/([A-Za-z0-9_-]{21})(?:/edit)?\z}.match(path.to_s)
          return current_client.client_secret_credentials.find_by!(public_id: match[1]).public_id if match
        when "settings_telephone"
          match = %r{\A/identity/telephones/([A-Za-z0-9_-]{21})/edit\z}.match(path.to_s)
          return current_client.client_telephones.find_by!(public_id: match[1]).public_id if match
        end
        nil
      end

      def redirect_to_bootstrap_choice
        return if reject_step_up_for_authentication_context!

        scope = requested_step_up_scope(StepUpScopeCatalog::APP)
        requested_step_up_return_to(scope: scope, allowed_scopes: StepUpScopeCatalog::APP)
        if current_session_token.established_authentication_method == "secret"
          return render plain: t("errors.messages.invalid_request"), status: :bad_request
        end

        redirect_to(
          base_app_verification_setup_path(scope: scope, pt: params[:pt], ri: params[:ri]), status: :see_other,
        )
      end

      def bootstrap_registration_methods = %i(passkey totp)

      def bootstrap_scope_permitted?(scope) = scope != "settings_secret_credential"

      def actor_verification_path(**args)
        base_app_verification_path(**args)
      end
    end
  end
end
