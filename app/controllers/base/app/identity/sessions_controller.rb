# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class SessionsController < BaseController
        include ::SurfaceInertiaPage
        include ::SessionTimestampHelper

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :set_session, only: %i(show destroy)

        def index
          authorize!(ClientToken, to: :index?)
          sessions = visible_sessions.order(created_at: :desc)
          render inertia: true, props: sessions_index_props(sessions)
        end

        def show
          authorize!(@session)
          render inertia: true, props: {
            title: t(".page_title"),
            session: serialize_session(@session),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: base_app_identity_sessions_path(ri: params[:ri]),
            },
          }
        end

        def destroy
          authorize!(@session)
          return redirect_to(
            base_app_identity_sessions_path(ri: params[:ri]),
            status: :see_other,
          ) if current_session_record?(@session)

          revoke_selected_session!(@session)
          redirect_to(base_app_identity_sessions_path(ri: params[:ri]), status: :see_other)
        end

        private

        def visible_sessions = current_client.client_tokens.session_inventory

        def set_session = @session = visible_sessions.find_by!(public_id: params.expect(:id))

        def current_session_record?(session)
          return false unless session

          session.id == current_session&.id ||
            session.public_id == current_session_public_id ||
            (session.device_session_id.present? && session.device_session_id == current_session&.device_session_id)
        end

        def sessions_index_props(sessions)
          serialized = sessions.map { |session| serialize_session(session) }

          {
            title: "Sessions",
            empty_message: t("base.app.identity.sessions.index.empty_message"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: base_app_identity_path(ri: params[:ri]),
            },
            table_headings: {
              session: "Session",
              kind: "Kind",
              binding: "Binding",
              last_activity: "Last activity",
              created: "Created",
              refresh_expires: "Refresh expires",
            },
            current_label: "current",
            revoke_label: "Revoke",
            revoke_confirm: t("base.app.identity.sessions.index.revoke_confirm"),
            bulk_revocation: (serialized.any? { |session| !session.fetch(:current) }) ? bulk_revocation_props : nil,
            sessions: serialized,
          }
        end

        def bulk_revocation_props
          {
            others_label: t("sign.app.settings.sessions.revoke.others_button"),
            others_confirm: t("sign.app.settings.sessions.revoke.others_confirm"),
            others_url: base_app_identity_other_sessions_path(ri: params[:ri]),
          }
        end

        def serialize_session(session)
          {
            public_id: session.public_id,
            status: session.user_token_status_id.to_s,
            kind: session.user_token_kind_id.to_s,
            binding: session.dbsc_enabled? ? "DBSC" : "NORMAL",
            last_activity: localized_session_timestamp(session.last_used_at || session.created_at),
            created: localized_session_timestamp(session.created_at),
            refresh_expires: localized_session_timestamp(session.discarded_at),
            current: current_session_record?(session),
            revoke_url: base_app_identity_session_path(session.public_id, ri: params[:ri]),
          }
        end

        def revoke_selected_session!(session)
          AuthenticationSelectedSessionRevoker.call(
            owner: current_client,
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
