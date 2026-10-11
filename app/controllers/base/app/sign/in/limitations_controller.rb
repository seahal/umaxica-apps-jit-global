# typed: false
# frozen_string_literal: true

module Base
  module App
    module Sign
      module In
        # Base sign-in limitation ceremony for OIDC resume and social handoff.
        class LimitationsController < Base::App::ApplicationController
          include ::SurfaceInertiaPage

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          before_action :load_resolution

          def show
            return render_invalid_resolution unless resolution_loaded?

            load_session_inventory
            render inertia: true, props: limitation_page_props
          end

          def update
            return render_invalid_resolution unless resolution_loaded?

            token = selected_token
            unless token_belongs_to_actor?(token)
              @form_error = t("base.app.sign.in.limitations.revoke_failed")
              load_session_inventory
              return render_limitation_page(status: :unprocessable_content)
            end

            @resolution&.mark_session_selected!(session_ref: params[:session_ref])
            revocation = AuthenticationSelectedSessionRevoker.call(
              owner: @actor,
              token: token,
              reason: "session_limit_limitation_selected_revoke",
            )
            unless revocation.success?
              @form_error = t("base.app.sign.in.limitations.revoke_failed")
              load_session_inventory
              return render_limitation_page(status: :unprocessable_content)
            end
            token.reload.revoke! if token.currently_usable?

            if hard_reject_still_applies?
              @form_notice = t("base.app.sign.in.limitations.capacity_still_full")
              load_session_inventory
              return render_limitation_page(status: :unprocessable_content)
            end

            if social_resolution?
              promote_social_resolution_session
            else
              resume_authorization_after_resolution
            end
          end

          def destroy
            return render_invalid_resolution unless resolution_loaded?

            if social_resolution?
              return redirect_to(
                auth_app_sign_in_url(
                  host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                ),
                allow_other_host: cross_host_redirect_allowed?,
                status: :see_other,
              )
            end

            @resolution.cancel!
            redirect_to(
              auth_app_sign_in_url(
                host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
              ),
              allow_other_host: cross_host_redirect_allowed?,
              status: :see_other,
            )
          end

          private

          def render_limitation_page(status:)
            render inertia: "base/app/sign/in/limitations/show", props: limitation_page_props, status: status
          end

          def limitation_page_props
            {
              title: "Session limit",
              heading: "Session limit",
              description: "Your credential was verified, but this account already has the maximum number " \
                           "of live sessions. Revoke one existing session to continue signing in.",
              session_label: "Session",
              error: @form_error.presence,
              notice: @form_notice.presence,
              action: base_app_sign_in_limitation_path,
              cancel_action: base_app_sign_in_limitation_path(resolution_query_parameters),
              submit_label: "Revoke and continue",
              cancel_label: "Cancel sign-in",
              resolution: resolution_field,
              sessions: Array(@sessions).map { |session_record| serialize_limitation_session(session_record) },
            }
          end

          def resolution_field
            if @social_resolution_token.present?
              { field: "social_resolution", value: @social_resolution_token }
            else
              { field: "resolution_challenge", value: @resolution_challenge }
            end
          end

          def resolution_query_parameters
            if @social_resolution_token.present?
              { social_resolution: @social_resolution_token }
            else
              { resolution_challenge: @resolution_challenge }
            end
          end

          def serialize_limitation_session(session_record)
            {
              session_ref: SessionLimitResolutionTokenRef.issue(session_record),
              restriction_label: session_record.restricted? ? "Restricted" : "Normal",
              created_label: "Created #{l(session_record.created_at, format: :short)}",
              last_used_label: session_record.last_used_at.presence &&
                "Last used #{l(session_record.last_used_at, format: :short)}",
              revoke_label: "Revoke this session",
            }
          end

          def load_resolution
            @resolution_challenge = params[:resolution_challenge].to_s
            @social_resolution_token = params[:social_resolution].to_s
            return if @resolution_challenge.blank? && @social_resolution_token.blank?
            return if @resolution_challenge.present? && @social_resolution_token.present?

            @resolution = ClientSessionLimitResolutionTransaction.find_active_by_challenge(@resolution_challenge)
            if @resolution
              @actor = Client.find_by(public_id: @resolution.actor_ref)
              @oidc_transaction = @resolution.oidc_authorization_transaction
              return
            end

            load_social_resolution
          end

          def render_invalid_resolution
            render plain: t("base.app.sign.in.limitations.invalid_or_expired"), status: :gone
          end

          def resolution_loaded?
            @resolution.present? || social_resolution?
          end

          def social_resolution?
            @social_resolution_payload.present?
          end

          def load_social_resolution
            return if @social_resolution_token.blank?

            verifier = Rails.application.message_verifier(:social_session_limit_limitation)
            payload = verifier.verify(@social_resolution_token)
            expires_at = Time.zone.parse(payload.fetch("expires_at").to_s)
            return if expires_at.blank? || expires_at <= Time.current

            @actor =
              AppTicketRecord.connected_to(role: :writing) do
                Client.find_by(public_id: payload.fetch("actor_ref"))
              end
            return unless @actor

            @social_resolution_payload = payload
          rescue ActiveSupport::MessageVerifier::InvalidSignature, KeyError, ArgumentError, TypeError
            @social_resolution_payload = nil
          end

          def load_session_inventory
            @sessions =
              AppTicketRecord.connected_to(role: :writing) do
                ClientToken.not_revoked
                  .where(user_id: @actor.id, rotated_at: nil)
                  .order(created_at: :desc)
                  .to_a
              end
          end

          def selected_token
            SessionLimitResolutionTokenRef.find_client_token(params[:session_ref])
          end

          def token_belongs_to_actor?(token)
            token.present? && @actor.present? && token.user_id == @actor.id && token.currently_usable?
          end

          def hard_reject_still_applies?
            AppTicketRecord.connected_to(role: :writing) do
              ClientToken.not_revoked.where(user_id: @actor.id, rotated_at: nil).count >=
                ClientToken::MAX_TOTAL_SESSIONS_PER_USER
            end
          end

          def promote_social_resolution_session
            if current_session&.restricted?
              return render_invalid_resolution unless current_session.user_id == @actor.id

              if @social_resolution_payload["session_ref"].present?
                return render_invalid_resolution unless current_session.public_id ==
                  @social_resolution_payload["session_ref"]
              end

              current_session.promote_to_active!
            else
              login_result = log_in(
                @actor,
                record_login_audit: true,
                token_kind_id: "BROWSER_WEB",
                require_totp_check: false,
                audit_context: { auth_method: "social_session_limitation" },
                bootstrap_actor: true,
                authentication_event_at: current_authentication_event_at,
              )
              return render_invalid_resolution unless login_result[:status] == :success
            end

            redirect_to(base_app_root_path(ri: params[:ri]), status: :see_other)
          end

          def resume_authorization_after_resolution
            @oidc_transaction.consume!
            @resolution.finalize!
            issue_authorization_code!
          end

          def issue_authorization_code!
            result = ::OidcAuthorizeCoordinator.call(
              params: @oidc_transaction.authorize_params,
              resource: @actor,
              session_token: current_session,
              auth_method: @oidc_transaction.auth_method,
              acr: @oidc_transaction.acr,
              authentication_event_at: @oidc_transaction.authenticated_at,
            )

            if result.success?
              redirect_to_jump_url(result.redirect_url)
            else
              render json: { error: result.error, error_description: result.error_description },
                     status: :bad_request
            end
          end
        end
      end
    end
  end
end
