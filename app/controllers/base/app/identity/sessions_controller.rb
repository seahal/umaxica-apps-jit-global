# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class SessionsController < BaseController
        include ::SurfaceInertiaPage

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
            title: t("base.shared.identity.sessions.title"),
            expires_at_description: t("base.shared.identity.sessions.expires_at_description"),
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
          serialized = sessions.map { |session| serialize_session(session).merge(revoke: session_revoke_action(session)) }
          {
            title: t("base.shared.identity.sessions.title"),
            empty_message: t("base.shared.identity.sessions.empty"),
            expires_at_description: t("base.shared.identity.sessions.expires_at_description"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: base_app_identity_path(ri: params[:ri]),
            },
            columns: session_columns,
            bulk_revocations: serialized.any? { |session| session[:revoke] } ? bulk_revocation_props : nil,
            sessions: serialized,
          }
        end

        def session_columns
          %i(device last_activity created expires_at status action).index_with do |column|
            t("base.shared.identity.sessions.columns.#{column}")
          end
        end

        def serialize_session(session)
          ::Base::Identity::SessionPresenter.new.present(
            session, current: current_session_record?(session), surface: :app,
          )
        end

        def session_revoke_action(session)
          return if current_session_record?(session)

          {
            label: t("base.shared.identity.sessions.revoke"),
            href: base_app_identity_session_path(session.public_id, ri: params[:ri]),
            confirm: t("base.app.identity.sessions.index.revoke_confirm"),
          }
        end

        def bulk_revocation_props
          {
            others: {
              label: t("sign.app.settings.sessions.revoke.others_button"),
              href: base_app_identity_other_sessions_path(ri: params[:ri]),
              confirm: t("sign.app.settings.sessions.revoke.others_confirm"),
            },
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
