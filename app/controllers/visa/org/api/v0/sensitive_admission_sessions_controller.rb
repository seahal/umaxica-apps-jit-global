# typed: false
# frozen_string_literal: true

module Visa
  module Org
    module Api
      module V0
        # Cancels Visa-owned O-9 admissions before Base revokes the matching RP-local session.
        class SensitiveAdmissionSessionsController < ActionController::API
          include ::DefaultNoStore

          AUTHENTICATION_MODE = :open
          CLIENT_ID = "base-org-ww"
          RESOURCE_TYPE = "operator"

          prepend_before_action :apply_default_no_store
          before_action :authenticate_base_caller!

          public

          def create
            admission_ref = params.expect(:admission_ref)
            rp_session_ref = params.expect(:rp_session_ref)
            browser_binding_digest = params.expect(:browser_binding_digest)
            unless admission_ref.is_a?(String) &&
                admission_ref.match?(OperatorVisaSensitiveAdmission::PUBLIC_REF_PATTERN) &&
                rp_session_ref.is_a?(String) && rp_session_ref.present? && rp_session_ref.length <= 64 &&
                browser_binding_digest.is_a?(String) &&
                browser_binding_digest.match?(OperatorVisaSensitiveAdmission::DIGEST_PATTERN)
              return render_bad_request
            end

            VisaSensitiveAdmissionBrowserConfirmer.call!(
              actor: @actor, token: @root_token, grant: @grant, payload: @payload,
              client_id: CLIENT_ID, rp_session_ref:, public_ref: admission_ref,
              browser_digest: browser_binding_digest,
            )
            head :no_content
          rescue VisaSensitiveAdmissionBrowserConfirmer::InvalidAuthority
            head :not_found
          rescue ActionController::ParameterMissing
            render_bad_request
          rescue ActiveRecord::ActiveRecordError, PG::Error => e
            Rails.logger.error(
              "visa.o9_browser_confirmation_unavailable error_class=#{e.class.name} realm=org",
            )
            render json: { error: "temporarily_unavailable" }, status: :service_unavailable
          end

          def update
            reference = params.expect(:rp_session_ref)
            unless reference.is_a?(String) && reference.match?(OperatorVisaSensitiveAdmission::PUBLIC_REF_PATTERN)
              return render_bad_request
            end

            VisaSensitiveAdmissionSessionRevoker.call!(
              actor: @actor, token: @root_token, grant: @grant, actor_subject: @subject,
              grant_sid: @grant_sid, client_id: CLIENT_ID, rp_session_ref: reference,
            )
            head :no_content
          rescue VisaSensitiveAdmissionSessionRevoker::InvalidAuthority
            render json: { error: "invalid_token" }, status: :unauthorized
          rescue ActionController::ParameterMissing
            render_bad_request
          rescue ActiveRecord::ActiveRecordError, PG::Error => e
            Rails.logger.error(
              "visa.o9_session_cancellation_unavailable error_class=#{e.class.name} realm=org",
            )
            render json: { error: "temporarily_unavailable" }, status: :service_unavailable
          end

          private

          def authenticate_base_caller!
            response.headers["Cache-Control"] = "no-store"
            url = "#{request.base_url}#{request.path}"
            assertion_valid = OidcClientRegistry.authenticate_assertion(
              CLIENT_ID, request.headers["X-Client-Assertion"].to_s, token_url: url,
            )
            return render(json: { error: "invalid_client" }, status: :unauthorized) unless assertion_valid

            auth = OidcAccessTokenAuthenticator.call(
              access_token: request.authorization.to_s.delete_prefix("Bearer "),
              resource_type: RESOURCE_TYPE,
              host: request.host,
              authorization_scheme: "Bearer",
            )
            unless auth.success? && auth.payload["client_id"] == CLIENT_ID && auth.resource.is_a?(Operator)
              return render(json: { error: "invalid_token" }, status: :unauthorized)
            end

            @grant_sid = auth.payload["sid"]
            @subject = auth.payload["sub"]
            @payload = auth.payload
            @actor = auth.resource
            @grant = OpOrgGrant.includes(:operator_token).find_by(public_id: @grant_sid, oidc_client_id: CLIENT_ID)
            unless @grant&.active?
              return render(json: { error: "invalid_token" }, status: :unauthorized)
            end

            @root_token = @grant.operator_token
          rescue ActiveRecord::ActiveRecordError, PG::Error => e
            Rails.logger.error(
              "visa.o9_session_cancellation_authentication_unavailable " \
              "error_class=#{e.class.name} realm=org",
            )
            render json: { error: "temporarily_unavailable" }, status: :service_unavailable
          end

          def render_bad_request
            render json: { error: "invalid_request" }, status: :bad_request
          end
        end
      end
    end
  end
end
