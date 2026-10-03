# typed: false
# frozen_string_literal: true

module Base
  module App
    module Sign
      module In
        # Base sign-in limitation ceremony for OIDC resume and social handoff.
        #
        # Two pending states can reach this page, and neither carries a session:
        # an OIDC authorization resume holds a ClientSessionLimitResolutionTransaction
        # (challenge in the request), and a social sign-in holds its ClientSignInFlow in
        # SESSION_LIMIT_PENDING through this browser's flow locator. After the user
        # revokes a session, the new root login is issued only by log_in, which
        # re-counts the limit and re-checks the cooldown under the actor lock.
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
              complete_social_resolution
            else
              resume_authorization_after_resolution
            end
          end

          def destroy
            return render_invalid_resolution unless resolution_loaded?

            # Cancelling ends only this pending sign-in; no existing session is touched.
            if social_resolution?
              AppTicketRecord.connected_to(role: :writing) { @pending_sign_in_flow.fail_sign_in! }
              clear_current_sign_in_flow_locator!
            else
              @resolution.cancel!
            end
            redirect_to_surface_url(
              auth_app_sign_in_url(
                host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                protocol: "https",
              ),
              status: :see_other,
            )
            # The cancel button issues an Inertia visit, and sign-in lives on the Auth host, so a
            # plain 303 would be followed by fetch cross-origin and the page would never change.
            convert_redirect_to_inertia_location!
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
            return nil if social_resolution?

            { field: "resolution_challenge", value: @resolution_challenge }
          end

          def resolution_query_parameters
            return {} if social_resolution?

            { resolution_challenge: @resolution_challenge }
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
            if @resolution_challenge.present?
              @resolution = ClientSessionLimitResolutionTransaction.find_active_by_challenge(@resolution_challenge)
              return unless @resolution

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
            @pending_sign_in_flow.present?
          end

          # The pending flow is found only through the locator this browser's
          # Rails session holds; the actor is the flow's principal, never a
          # request parameter or a principal id stored beside the locator.
          def load_social_resolution
            flow = current_db_sign_in_flow_for_sequence
            return unless flow.is_a?(ClientSignInFlow) && flow.sign_in_session_limit_pending?

            actor = AppTicketRecord.connected_to(role: :writing) { flow.principal }
            return unless actor

            @pending_sign_in_flow = flow
            @actor = actor
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

          def complete_social_resolution
            if @pending_sign_in_flow.authentication_event_at
              authorize!(@pending_sign_in_flow, to: :manage_session_limit?, context: { user: @actor })
              locator = session[SignInCycleLocator::SESSION_KEYS.fetch(:app)]
              result = LocalAuthenticationSessionCommitter.resume_pending!(
                controller: self, flow: @pending_sign_in_flow, actor: @actor, nonce: locator.fetch("nonce"),
              )
              return render_invalid_resolution unless result.fetch(:status) == :success

              return redirect_to(base_app_dashboard_path(ri: params[:ri]), status: :see_other)
            end
            return render_invalid_resolution unless promote_current_session_limit_cycle!(@actor)

            redirect_to(base_app_dashboard_path(ri: params[:ri]), status: :see_other)
          rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound,
                 ActiveRecord::SoleRecordExceeded, AuthCeremonySession::InvalidTransition
            render_invalid_resolution
          end

          def resume_authorization_after_resolution
            return render_invalid_resolution unless promote_oidc_resolution_session!

            finalization =
              @oidc_transaction.finalize_base! do |_locked, _finalization_time|
                { status: :success, browser_session_ref: current_session.public_id }
              end
            return render_invalid_resolution unless finalization[:status] == :success

            @resolution.finalize!
            issue_authorization_code!
          end

          # The OIDC resume issued nothing while the limit was full. The root login
          # is committed here, through the same final boundary as any sign-in.
          def promote_oidc_resolution_session!
            login_result = log_in(
              @actor,
              establishment: :root_login,
              record_login_audit: true,
              token_kind_id: "BROWSER_WEB",
              require_totp_check: false,
              audit_context: { auth_method: "session_limit_promotion", oidc_client_id: @oidc_transaction.client_id },
              authentication_event_at: @oidc_transaction.authenticated_at,
            )
            login_result[:status] == :success
          end

          def issue_authorization_code!
            result = ::OidcAuthorizeCoordinator.call(
              params: @oidc_transaction.authorize_params,
              resource: @actor,
              session_token: current_session,
              auth_method: @oidc_transaction.auth_method,
              acr: @oidc_transaction.acr,
              authentication_event_at: @oidc_transaction.authenticated_at,
              authorization_transaction_ref: @oidc_transaction.transaction_id,
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
