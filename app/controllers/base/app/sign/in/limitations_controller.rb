# typed: false
# frozen_string_literal: true

module Base
  module App
    module Sign
      module In
        # Base sign-in limitation ceremony for OIDC resume and social handoff.
        #
        # A pending sign-in reaches this page through the browser-bound
        # SessionLimitResolutionTransaction. The parent sign-in flow remains in
        # SESSION_ISSUANCE_PENDING while the child owns the selection and revoke
        # ceremony. After the user revokes a session, the new root login is issued
        # only by log_in, which re-counts the limit and re-checks the cooldown.
        class LimitationsController < Base::App::AuthorityController
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

            unless resolve_selected_session(token)
              @form_error = t("base.app.sign.in.limitations.revoke_failed")
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
            return render_invalid_resolution unless cancel_pending_resolution!

            # Base's neutral entry owns fresh admission. Cancellation grants no Auth continuity.
            redirect_to(base_app_sign_show_path(ri: params[:ri]), status: :see_other)
            # The entry is a plain document, not an Inertia page.
            convert_redirect_to_inertia_location!
          end

          private

          def resolve_selected_session(token)
            return false unless @resolution && @resolution_binding.present?

            @resolution.select_session!(
              actor: @actor,
              challenge: @resolution_challenge,
              session_ref: token.public_id,
              browser_binding_digest: @resolution.class.digest_challenge(@resolution_binding),
            )
            @resolution.resolve!(
              actor: @actor,
              challenge: @resolution_challenge,
              browser_binding_digest: @resolution.class.digest_challenge(@resolution_binding),
            )
            true
          rescue FlowInvalidTransition, ActiveRecord::RecordNotFound
            false
          end

          def cancel_pending_resolution!
            return false unless @resolution && @resolution_binding.present?

            @resolution.cancel!(
              actor: @actor,
              challenge: @resolution_challenge,
              browser_binding_digest: @resolution.class.digest_challenge(@resolution_binding),
            )
            flow = ClientSignInFlow.find(@resolution.sign_in_flow_id)
            flow.cancel_sign_in! unless flow.sign_in_completed? || flow.sign_in_expired? ||
              flow.sign_in_cancelled? || flow.sign_in_halted?
            if @oidc_transaction&.secret_sign_in_flow_id
              credential = ClientSecretCredential.find_by(
                client_id: @actor.id, claim_sign_in_flow_ref: flow.public_id,
              )
              ClientSecretClaimFinalizer.call!(
                credential: credential, purge_after: ClientSecretLifetimesValue.purge_delay,
              ) if credential
            end
            clear_current_sign_in_flow_locator!
            session[:inertia_clear_history] = true
            true
          rescue FlowInvalidTransition, ActiveRecord::RecordNotFound
            false
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
            { field: "resolution_challenge", value: @resolution_challenge }
          end

          def resolution_query_parameters
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
            @resolution_challenge = resolution_challenge_from_session
            return load_social_resolution if @resolution_challenge.blank?
            return if requested_resolution_challenge_mismatch?

            load_resolution_transaction
          end

          def resolution_challenge_from_session
            gate = session[GATE_SESSION_KEY]
            challenge = gate.is_a?(Hash) ? gate["resolution_challenge"].to_s : ""
            challenge.presence
          end

          def requested_resolution_challenge_mismatch?
            requested_challenge = params[:resolution_challenge].to_s
            requested_challenge.present? && requested_challenge != @resolution_challenge
          end

          def load_resolution_transaction
            @resolution_binding = session_limit_resolution_binding
            @resolution = ClientSessionLimitResolutionTransaction.find_by(
              challenge_digest: ClientSessionLimitResolutionTransaction.digest_challenge(@resolution_challenge),
            )
            return unless @resolution && @resolution_binding.present?

            validate_loaded_resolution
          end

          def validate_loaded_resolution
            @actor = Client.find_by(public_id: @resolution.actor_ref)
            @oidc_transaction =
              AppTicketRecord.connected_to(role: :writing) do
                ClientOidcAuthorizationTransaction.find_by(id: @resolution.oidc_authorization_transaction_id)
              end
            flow = ClientSignInFlow.find_by(id: @resolution.sign_in_flow_id)
            now = ClientSignInFlow.database_now
            valid_binding = ActiveSupport::SecurityUtils.secure_compare(
              @resolution.browser_binding_digest,
              @resolution.class.digest_challenge(@resolution_binding),
            )
            valid_parent = valid_resolution_parent?(flow, now)
            valid_oidc = valid_resolution_oidc?(now)
            @resolution = nil unless @actor && valid_binding && valid_parent && valid_oidc &&
              (@resolution.open? || @resolution.resolved?)
          end

          def valid_resolution_parent?(flow, now)
            flow && @actor && flow.principal_id == @actor.id && !flow.expired?(now) &&
              !flow.sign_in_completed? && !flow.sign_in_cancelled? && !flow.sign_in_halted?
          end

          def valid_resolution_oidc?(now)
            return true unless @oidc_transaction

            @oidc_transaction.actor_ref == @actor.public_id && @oidc_transaction.authenticated? &&
              @oidc_transaction.base_finalized_at.nil? && !@oidc_transaction.expired?(now: now) &&
              !@oidc_transaction.login_challenge_expired?(now: now)
          end

          def render_invalid_resolution
            render plain: t("base.app.sign.in.limitations.invalid_or_expired"), status: :gone
          end

          def resolution_loaded?
            @resolution.present?
          end

          def social_resolution?
            @resolution.present? && @oidc_transaction.nil?
          end

          # The pending flow is found only through the locator this browser's
          # Rails session holds; the actor is the flow's principal, never a
          # request parameter or a principal id stored beside the locator.
          def load_social_resolution
            nil
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

          def session_limit_still_reached?
            AppTicketRecord.connected_to(role: :writing) do
              ClientToken.active_status.where(user_id: @actor.id).count >= ClientToken::MAX_SESSIONS_PER_USER ||
                ClientToken.not_revoked.where(user_id: @actor.id, rotated_at: nil).count >=
                  ClientToken::MAX_TOTAL_SESSIONS_PER_USER
            end
          end

          def complete_social_resolution
            return render_invalid_resolution unless promote_current_session_limit_cycle!(@actor)

            session[:inertia_clear_history] = true
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
                    next { status: :invalid_request } if locked.base_finalized_at || !@resolution.resolved?

                    login_result = promote_oidc_resolution_session!
                    next login_result unless login_result[:status] == :success

                    { status: :success, browser_session_ref: current_session.public_id }
                  end
                end
              end
            if finalization[:status] == :session_limit_pending
              @resolution = finalization.fetch(:resolution_transaction)
              @resolution_challenge = finalization.fetch(:resolution_challenge)
              @resolution_binding = finalization.fetch(:resolution_binding)
              @form_notice = t("base.app.sign.in.limitations.capacity_still_full")
              load_session_inventory
              return render_limitation_page(status: :unprocessable_content)
            end
            return render_invalid_resolution unless finalization[:status] == :success

            finalize_oidc_secret_claim! if @oidc_transaction.secret_sign_in_flow_id
            session[:inertia_clear_history] = true
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
              sign_in_flow: ClientSignInFlow.find(@resolution.sign_in_flow_id),
              record_login_audit: true,
              token_kind_id: "BROWSER_WEB",
              require_totp_check: false,
              audit_context: { auth_method: "session_limit_promotion", oidc_client_id: @oidc_transaction.client_id },
              authentication_event_at: @oidc_transaction.authenticated_at,
              oidc_authorization_transaction: @oidc_transaction,
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
            login_result
          end

          def oidc_secret_issuance_options
            return {} unless @oidc_transaction.secret_sign_in_flow_id
            unless @oidc_transaction.auth_method == "passcode"
              raise AuthenticationBase::SignInFlowIssuanceRejected, "Secret OIDC authentication method mismatch"
            end

            flow = ClientSignInFlow.find(@oidc_transaction.secret_sign_in_flow_id)
            flow.with_lock do
              return nil if flow.sign_in_failed? || flow.expired?(ClientSignInFlow.database_now)

              unless flow.sign_in_primary_pending? || flow.sign_in_session_issuance_pending?
                raise FlowInvalidTransition, "Secret OIDC handoff is not ready"
              end
            end
            { sign_in_flow: flow, established_authentication_method: "secret" }
          end

          def finalize_oidc_secret_claim!
            flow = ClientSignInFlow.find(@oidc_transaction.secret_sign_in_flow_id)
            credential = ClientSecretCredential.find_by!(
              client_id: @actor.id, claim_sign_in_flow_ref: flow.public_id,
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
