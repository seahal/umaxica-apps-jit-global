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

            revocation =
              if @oidc_transaction&.secret_sign_in_flow_id
                @resolution.with_secret_revocation_authority!(actor: @actor, challenge: @resolution_challenge) do
                  revoke_selected_session(token)
                end
              else
                revoke_selected_session(token)
              end
            unless revocation.success?
              @form_error = t("base.app.sign.in.limitations.revoke_failed")
              load_session_inventory
              return render_limitation_page(status: :unprocessable_content)
            end

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
          rescue ClientSessionLimitResolutionTransaction::InvalidSecretResolution
            render_invalid_resolution
          end

          def destroy
            return render_invalid_resolution unless resolution_loaded?

            # Cancelling ends only this pending sign-in; no existing session is touched.
            if social_resolution?
              cancel_pending_local_login!
              clear_current_sign_in_flow_locator!
            elsif @oidc_transaction.secret_sign_in_flow_id
              return render_invalid_resolution unless cancel_oidc_secret_login!
            else
              @resolution.cancel!
            end
            # Base's neutral entry owns fresh admission. Cancellation grants no Auth continuity.
            redirect_to(base_app_sign_show_path(ri: params[:ri]), status: :see_other)
          end

          private

          def revoke_selected_session(token)
            @resolution&.mark_session_selected!(session_ref: params[:session_ref])
            result = AuthenticationSelectedSessionRevoker.call(
              owner: @actor, token: token, reason: "session_limit_limitation_selected_revoke",
            )
            token.reload.revoke! if result.success? && token.currently_usable?
            result
          end

          def cancel_oidc_secret_login!
            canceled =
              @actor.with_lock do
                @oidc_transaction.with_lock do
                  @resolution.lock!
                  flow = @oidc_transaction.secret_sign_in_flow
                  flow.lock!
                  next false if @oidc_transaction.base_finalized_at || flow.token_id || flow.session_issued_at ||
                    !@oidc_transaction.authenticated? || !(@resolution.pending? || @resolution.session_selected?)

                  flow.fail_sign_in!(now: ClientSignInFlow.database_now) unless flow.sign_in_failed?
                  @resolution.cancel!(now: ClientSignInFlow.database_now)
                  true
                end
              end
            finalize_oidc_secret_claim! if canceled
            canceled
          end

          def cancel_pending_local_login!
            secret = @pending_sign_in_flow.authentication_method == "secret"
            AppTicketRecord.connected_to(role: :writing) do
              @pending_sign_in_flow.with_lock do
                @pending_sign_in_flow.fail_sign_in!
                if secret
                  ClientAuthCeremonySession.where(local_sign_in_flow_ref: @pending_sign_in_flow.public_id)
                    .lock.each { |ceremony| ceremony.cancel! unless ceremony.terminal? }
                end
              end
            end
            return unless secret

            AppZenithRecord.connected_to(role: :writing) do
              credential = ClientSecretCredential.find_by!(
                client_id: @actor.id, claim_sign_in_flow_ref: @pending_sign_in_flow.public_id,
              )
              ClientSecretClaimFinalizer.call!(
                credential: credential,
                purge_after: ClientSecretLifetimesValue.purge_delay,
              )
            end
          end

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
              @oidc_transaction =
                AppTicketRecord.connected_to(role: :writing) do
                  @resolution.oidc_authorization_transaction
                end
              now = ClientOidcAuthorizationTransaction.database_now
              unless @actor && @oidc_transaction.actor_ref == @actor.public_id &&
                  @oidc_transaction.authenticated? && @oidc_transaction.base_finalized_at.nil? &&
                  !@oidc_transaction.expired?(now: now) && !@oidc_transaction.login_challenge_expired?(now: now) &&
                  pending_oidc_secret_flow?(now)
                @resolution = nil
              end
              return
            end

            load_social_resolution
          end

          def pending_oidc_secret_flow?(now)
            return true unless @oidc_transaction.secret_sign_in_flow_id

            flow = @oidc_transaction.secret_sign_in_flow
            flow.principal_id == @actor.id && flow.authentication_method == "secret" &&
              flow.sign_in_session_limit_pending? && !flow.expired?(now) &&
              flow.token_id.nil? && flow.session_issued_at.nil?
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
              ClientToken.active_status.where(user_id: @actor.id).count >= ClientToken::MAX_SESSIONS_PER_USER ||
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
              if result.fetch(:status) == :session_limit_pending
                @form_notice = t("base.app.sign.in.limitations.capacity_still_full")
                load_session_inventory
                return render_limitation_page(status: :unprocessable_content)
              end
              unless result.fetch(:status) == :success
                Rails.logger.warn(
                  JitLogEvent.format(
                    "base.sign_in.local_resume.incomplete", result_status: result.fetch(:status).to_s,
                                                            request_id: request.request_id,
                  ),
                )
                return render_invalid_resolution
              end

              return redirect_to(base_app_dashboard_path(ri: params[:ri]), status: :see_other)
            end
            return render_invalid_resolution unless promote_current_session_limit_cycle!(@actor)

            redirect_to(base_app_dashboard_path(ri: params[:ri]), status: :see_other)
          rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound,
                 ActiveRecord::SoleRecordExceeded, AuthCeremonySession::InvalidTransition => e
            Rails.logger.warn(
              JitLogEvent.format(
                "base.sign_in.local_resume.refused", error_class: e.class.name,
                                                     source_location: e.backtrace&.first,
                                                     request_id: request.request_id,
              ),
            )
            render_invalid_resolution
          end

          def resume_authorization_after_resolution
            finalization =
              @actor.class.connection_class_for_self.connected_to(role: :writing) do
                @actor.with_lock do
                  @oidc_transaction.finalize_base! do |locked, _finalization_time|
                    @resolution.lock!
                    next { status: :invalid_request } if locked.base_finalized_at ||
                      !(@resolution.pending? || @resolution.session_selected?) || @resolution.expired?
                    next { status: :login_failed } unless promote_oidc_resolution_session!

                    { status: :success, browser_session_ref: current_session.public_id }
                  end
                end
              end
            return render_invalid_resolution unless finalization[:status] == :success

            finalize_oidc_secret_claim! if @oidc_transaction.secret_sign_in_flow_id
            @resolution.finalize!
            issue_authorization_code!
          rescue ArgumentError => e
            Rails.logger.warn(
              JitLogEvent.format(
                "base.sign_in.oidc_resume.refused", error_class: e.class.name,
                                                    source_location: e.backtrace&.first,
                                                    request_id: request.request_id,
              ),
            )
            render_invalid_resolution
          end

          # The OIDC resume issued nothing while the limit was full. The root login
          # is committed here, through the same final boundary as any sign-in.
          def promote_oidc_resolution_session!
            secret_options = oidc_secret_issuance_options
            return false if secret_options.nil?

            login_result = log_in(
              @actor,
              establishment: :root_login,
              record_login_audit: true,
              token_kind_id: "BROWSER_WEB",
              require_totp_check: false,
              audit_context: { auth_method: "session_limit_promotion", oidc_client_id: @oidc_transaction.client_id },
              authentication_event_at: @oidc_transaction.authenticated_at,
              **secret_options,
            )
            unless login_result[:status] == :success
              Rails.logger.warn(
                JitLogEvent.format(
                  "base.sign_in.oidc_resume.issuance_refused", status: login_result[:status],
                                                               request_id: request.request_id,
                ),
              )
            end
            login_result[:status] == :success
          end

          def oidc_secret_issuance_options
            return {} unless @oidc_transaction.secret_sign_in_flow_id
            unless @oidc_transaction.auth_method == "passcode"
              raise AuthenticationBase::SignInFlowIssuanceRejected, "Secret OIDC authentication method mismatch"
            end

            flow = @oidc_transaction.secret_sign_in_flow
            flow.with_lock do
              return nil if flow.sign_in_failed? || flow.expired?(ClientSignInFlow.database_now)

              flow.prepare_secret_oidc_issuance!(authorization_transaction: @oidc_transaction)
            end
            { sign_in_flow: flow, established_authentication_method: "secret" }
          end

          def finalize_oidc_secret_claim!
            credential = ClientSecretCredential.find_by!(
              client_id: @actor.id, claim_sign_in_flow_ref: @oidc_transaction.secret_sign_in_flow.public_id,
            )
            ClientSecretClaimFinalizer.call!(
              credential: credential, purge_after: ClientSecretLifetimesValue.purge_delay,
            )
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
