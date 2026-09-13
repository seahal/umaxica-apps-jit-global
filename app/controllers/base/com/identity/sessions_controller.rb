# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class SessionsController < ::Base::Com::ApplicationController
        include ::SurfaceInertiaPage
        include ::SessionTimestampHelper

        AUTHENTICATION_MODE = :private

        before_action :authenticate_visitor!
        before_action :set_session, only: %i(show destroy)

        def index
          authorize!(VisitorToken, to: :index?)
          @sessions = visible_sessions.order(created_at: :desc)
          render inertia: true, props: index_page_props
        end

        def show
          authorize!(@session)
          render inertia: true, props: show_page_props
        end

        def destroy
          authorize!(@session)
          revoke_selected_session!(@session) unless current_session_record?(@session)
          redirect_to(base_com_identity_sessions_path(ri: params[:ri]), status: :see_other)
        end

        private

        def index_page_props
          sessions = @sessions.map { |session| serialize_session_row(session) }
          {
            title: "Sessions",
            back_link: { label: "Back", href: base_com_identity_path(ri: params[:ri]) },
            columns: ["Session", "Kind", "Binding", "Last activity", "Created", "Refresh expires", ""],
            empty_message: t("base.com.identity.sessions.index.empty_message"),
            current_label: "current",
            bulk_actions: bulk_session_action_props(sessions),
            sessions: sessions,
          }
        end

        # Bulk revocation was only offered when another session existed, and the page keeps that
        # rule on the server: an action the actor cannot use is absent from the props, not hidden.
        def bulk_session_action_props(sessions)
          return unless sessions.any? { |session| !session.fetch(:current) }

          {
            revoke_others: {
              label: "Revoke other sessions",
              url: base_com_identity_other_sessions_path(ri: params[:ri]),
              confirm: t("base.com.identity.sessions.index.revoke_others_confirm"),
            },
          }
        end

        def serialize_session_row(session)
          current = current_session_record?(session)
          {
            public_id: session.public_id,
            current: current,
            status: session.visitor_token_status_id.to_s,
            kind: session.visitor_token_kind_id.to_s,
            binding: session.dbsc_enabled? ? "DBSC" : "NORMAL",
            last_activity: localized_session_timestamp(session.last_used_at || session.created_at),
            created: localized_session_timestamp(session.created_at),
            refresh_expires: localized_session_timestamp(session.discarded_at),
            revoke: if current
                      nil
                    else
                      {
                        label: "Revoke",
                        url: base_com_identity_session_path(session.public_id, ri: params[:ri]),
                        confirm: t("base.com.identity.sessions.index.revoke_confirm"),
                      }
                    end,
          }
        end

        def show_page_props
          {
            title: "Session",
            back_link: { label: "Back", href: base_com_identity_sessions_path(ri: params[:ri]) },
            items: [
              { term: "Session", description: @session.public_id },
              { term: "Kind", description: @session.visitor_token_kind_id.to_s },
              { term: "Binding", description: @session.dbsc_enabled? ? "DBSC" : "NORMAL" },
            ],
          }
        end

        def visible_sessions
          current_visitor.visitor_tokens.session_inventory
        end

        def set_session
          @session = visible_sessions.find_by!(public_id: params.expect(:id))
        end

        def current_session_record?(session)
          return false unless session

          session.id == current_session&.id ||
            session.public_id == current_session_public_id ||
            (session.device_session_id.present? && session.device_session_id == current_session&.device_session_id)
        end

        def revoke_selected_session!(session)
          AuthenticationSelectedSessionRevoker.call(
            owner: current_visitor,
            token: session,
            current_token: current_session,
            current_session_public_id: current_session_public_id,
            reason: "settings.session.revoke",
          )
        end
      end
    end
  end
end
