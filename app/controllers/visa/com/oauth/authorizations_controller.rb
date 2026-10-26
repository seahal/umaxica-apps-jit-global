# typed: false
# frozen_string_literal: true

module Visa
  module Com
    module Oauth
      class AuthorizationsController < ::Visa::Com::AuthorizationBaseController
        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        before_action :enforce_oauth_authorize_request_size!, only: :show

        public :create

        public

        def show
          validate_authorization_start_parameters!
          validate_authorization_request!

          if authorization_session_sufficient?
            issue_authorization_code!(current_visitor)
          elsif prompt_none_requested?
            redirect_login_required!
          else
            start_authorization_ceremony!
          end
        rescue OidcAuthorizeRequestResolver::UnsupportedPrompt => e
          render_unsupported_prompt!(e)
        rescue OidcAuthorizeRequestResolver::RequestError => e
          redirect_authorization_request_error!(e)
        # OidcAuthorizeRequestResolver raises ArgumentError with spec-level request
        # descriptions ("scope must include openid", "state is required"), and the registry
        # errors are equally spec-defined. RFC 6749 section 4.1.2.1 expects these in
        # error_description and they disclose nothing about stored data.
        rescue ArgumentError, OidcClientRegistry::ClientNotFound, OidcClientRegistry::InvalidRedirectUri => e
          render json: { error: "invalid_request", error_description: e.message }, status: :bad_request
        # RecordNotFound is different: its message names the model and the primary key that
        # was looked up. The client gets a fixed description; the detail goes to the log.
        rescue BaseAuthAdmissionCoordinator::Denied
          render json: { error: "invalid_request", error_description: "invalid authorization request" },
                 status: :bad_request
        rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError => e
          Rails.logger.error(
            JitLogEvent.format(
              "oidc.authorize.backend_failure",
              surface: oidc_result_surface,
              error_class: e.class.name,
              request_id: request.request_id,
            ),
          )
          render json: {
            error: "temporarily_unavailable",
            error_description: I18n.t("errors.rate_limit.backend_unavailable"),
          }, status: :service_unavailable
        rescue ActiveRecord::RecordNotFound => e
          Rails.logger.info(
            JitLogEvent.format(
              "oidc.authorize.invalid_request",
              error_class: e.class.name,
              oidc_client_id: params[:client_id].to_s.presence,
            ),
          )
          render json: { error: "invalid_request", error_description: "invalid authorization request" },
                 status: :bad_request
        end
      end
    end
  end
end
