# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module In
        class SessionsController < ApplicationController
          include SessionLimitGate
          include ::SurfaceInertiaPage

          AUTHENTICATION_MODE = :deny_all

          # `update` and `destroy` also answer with the session management page, so the component
          # cannot be derived from the action name.
          SESSION_PAGE_COMPONENT = "auth/com/sign/in/sessions/show"

          declare_authentication_mode! :open

          before_action :require_authentication_or_gate

          def show
            load_session_data
            render inertia: SESSION_PAGE_COMPONENT, props: session_page_props
          end

          def update
            @current_visitor = resolve_current_visitor
            return redirect_to_login unless @current_visitor

            ref = params[:ref]

            if ref.present?
              revoke_session_by_ref(@current_visitor, ref)
            else
              refs = Array(params[:revoke_refs]).compact_blank
              if refs.empty?
                load_session_data
                return render inertia: SESSION_PAGE_COMPONENT,
                              props: session_page_props,
                              status: :unprocessable_content
              end

              revoke_sessions_by_refs(@current_visitor, refs)
            end

            # The pending flow is the only thing to complete. log_in re-counts the
            # limit under the actor lock; while it is still full nothing is issued
            # and the page is shown again.
            if pending_session_limit_cycle? && promote_current_session_limit_cycle!(@current_visitor)
              consume_session_limit_gate!
              return redirect_to_sign_in_sequence!(
                pt: retrieve_pt.presence || session_limit_pt,
              )
            end

            load_session_data
            render inertia: SESSION_PAGE_COMPONENT, props: session_page_props
          end

          def destroy
            @current_visitor = resolve_current_visitor
            return redirect_to_login unless @current_visitor

            ref = params[:ref]

            if ref.present?
              revoke_session_by_ref(@current_visitor, ref)
              load_session_data
              render inertia: SESSION_PAGE_COMPONENT, props: session_page_props
            else
              # Cancelling ends only this pending flow; it issued nothing, and no
              # other session of the account is touched.
              cancel_pending_session_limit_resolution!
              consume_session_limit_gate!
              clear_current_sign_in_flow_locator!

              return head :no_content if request.format.json?

              redirect_to(
                auth_com_sign_in_path(ri: current_region_identifier),
                status: :see_other,
              )
            end
          end

          private

          # Only a verified sign-in flow waiting on the session limit opens this page.
          # A signed-in browser has nothing pending here.
          def require_authentication_or_gate
            return if pending_session_limit_cycle?

            if logged_in?
              head :forbidden
              return
            end

            redirect_to_login
          end

          def pending_session_limit_cycle?
            session_limit_resolution.present?
          end

          def redirect_to_login
            redirect_to(
              auth_com_sign_in_path(ri: current_region_identifier),
              status: :see_other,
            )
          end

          # The actor is the pending flow's principal, read from the flow this
          # browser's locator names; never a principal id kept in the session.
          def resolve_current_visitor
            resolution = session_limit_resolution
            return unless resolution

            Visitor.find_by(public_id: resolution.actor_ref)
          end

          def load_session_data
            @current_visitor = resolve_current_visitor
            return unless @current_visitor

            @active_sessions = @current_visitor.visitor_tokens.active_status.order(created_at: :desc)
            @restricted_sessions = @current_visitor.visitor_tokens.restricted_status.order(created_at: :desc)
            @current_session_public_id = current_session_public_id
          end

          # The session management page. Every string, timestamp and URL is finished here; the
          # signed ref is the only session identifier that crosses.
          def session_page_props
            active_sessions = @active_sessions.to_a
            restricted_sessions = @restricted_sessions.to_a

            {
              title: I18n.t("sign.app.in.session.title"),
              heading: I18n.t("sign.app.in.session.title"),
              description: I18n.t("sign.app.in.session.description"),
              alert: @session_alert.presence,
              notice: @session_notice.presence,
              restricted_notice:
                current_session_restricted? ? I18n.t("sign.app.in.session.restricted_notice") : nil,
              form: {
                action: auth_com_sign_in_session_path(ri: current_region_identifier),
                submit_label: I18n.t("sign.app.in.session.revoke_selected"),
              },
              cancel: {
                action: auth_com_sign_in_session_path(ri: current_region_identifier),
                label: I18n.t("sign.app.in.session.cancel_logout"),
                confirm: I18n.t("sign.app.in.session.cancel_logout_confirm"),
              },
              active_sessions: active_sessions.any? ? active_sessions_props(active_sessions) : nil,
              restricted_sessions:
                restricted_sessions.any? ? restricted_sessions_props(restricted_sessions) : nil,
            }
          end

          def active_sessions_props(sessions)
            {
              heading: I18n.t("sign.app.in.session.active_sessions"),
              count_label: "(#{sessions.count}/#{VisitorToken::MAX_SESSIONS_PER_VISITOR})",
              revoke_label: I18n.t("sign.app.in.session.revoke"),
              items: sessions.map do |session|
                session_item_props(session, label: I18n.t("sign.app.in.session.session_label"), revocable: true)
              end,
            }
          end

          def restricted_sessions_props(sessions)
            {
              heading: I18n.t("sign.app.in.session.restricted_sessions"),
              items: sessions.map do |session|
                session_item_props(session, label: I18n.t("sign.app.in.session.pending_session"), revocable: false)
              end,
            }
          end

          def session_item_props(session, label:, revocable:)
            current = session.public_id == @current_session_public_id

            {
              label: label,
              current: current,
              current_label: current ? I18n.t("sign.app.in.session.current") : nil,
              created_at_label: I18n.t("sign.app.in.session.created_at"),
              created_at: l(session.created_at, format: :short),
              last_used_at_label: session.last_used_at ? I18n.t("sign.app.in.session.last_used_at") : nil,
              last_used_at: session.last_used_at ? l(session.last_used_at, format: :short) : nil,
              ref: (revocable && !current) ? session.signed_ref : nil,
            }
          end

          def revoke_session_by_ref(visitor, ref)
            token = VisitorToken.find_from_signed_ref(ref)
            unless token && allowed_to?(:destroy?, token, context: { user: visitor })
              return
            end

            if token.public_id == current_session_public_id
              return
            end

            return resolve_child_session!(visitor, token) if session_limit_resolution

            AuthenticationSelectedSessionRevoker.call(
              owner: visitor,
              token: token,
              current_token: current_session,
              current_session_public_id: current_session_public_id,
              reason: "session_limit_selected_revoke",
            )
          end

          def revoke_sessions_by_refs(visitor, refs)
            if session_limit_resolution
              token = VisitorToken.find_from_signed_ref(refs.first)
              return 0 unless token

              return resolve_child_session!(visitor, token) ? 1 : 0
            end

            ComTicketRecord.connected_to(role: :writing) do
              VisitorToken.transaction do
                VisitorToken.find_from_signed_refs(refs).each do |token|
                  next unless token && allowed_to?(:destroy?, token, context: { user: visitor })
                  next if token.public_id == current_session_public_id

                  AuthenticationSelectedSessionRevoker.call(
                    owner: visitor,
                    token: token,
                    current_token: current_session,
                    current_session_public_id: current_session_public_id,
                    reason: "session_limit_selected_revoke",
                  )
                end
              end
            end
          end

          def resolve_child_session!(actor, token)
            resolution = session_limit_resolution
            return false unless resolution && session_limit_resolution_binding

            challenge = session[GATE_SESSION_KEY]["resolution_challenge"]
            binding_digest = resolution.class.digest_challenge(session_limit_resolution_binding)
            resolution.select_session!(
              actor: actor,
              challenge: challenge,
              session_ref: token.public_id,
              browser_binding_digest: binding_digest,
            )
            resolution.resolve!(
              actor: actor,
              challenge: challenge,
              browser_binding_digest: binding_digest,
            )
            true
          rescue FlowInvalidTransition, ActiveRecord::RecordNotFound
            false
          end

          def cancel_pending_session_limit_resolution!
            resolution = session_limit_resolution
            if resolution
              actor = Visitor.find_by(public_id: resolution.actor_ref)
              binding = session_limit_resolution_binding
              challenge = session[GATE_SESSION_KEY]["resolution_challenge"]
              resolution.cancel!(
                actor: actor,
                challenge: challenge,
                browser_binding_digest: resolution.class.digest_challenge(binding),
              ) if actor && binding
            end

            flow = current_db_sign_in_flow_for_sequence
            if flow && !flow.sign_in_completed? && !flow.sign_in_expired? && !flow.sign_in_cancelled? &&
                !flow.sign_in_halted?
              with_sign_in_flow_writing(flow) { flow.cancel_sign_in! }
            end
            clear_current_sign_in_flow_locator!
          end
        end
      end
    end
  end
end
