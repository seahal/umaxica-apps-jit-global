# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class SessionsController < ::Base::Com::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_visitor!
        before_action :set_session, only: %i(show destroy)

        def index
          authorize!(VisitorToken, to: :index?)
          @sessions = visible_sessions.order(created_at: :desc)
          render inertia: true, props: index_page_props
        end

        def show
          authorize!(@session)
          row = serialize_session_row(@session)
          render inertia: true, props: {
            title: t("base.shared.identity.sessions.title"),
            back_link: { label: t("sign.app.settings.show.back"), href: base_com_identity_sessions_path(ri: params[:ri]) },
            expires_at_description: t("base.shared.identity.sessions.expires_at_description"),
            session: row,
            columns: session_columns,
          }
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
            title: t("base.shared.identity.sessions.title"),
            back_link: { label: t("sign.app.settings.show.back"), href: base_com_identity_path(ri: params[:ri]) },
            empty_message: t("base.shared.identity.sessions.empty"),
            expires_at_description: t("base.shared.identity.sessions.expires_at_description"),
            columns: session_columns,
            bulk_revocations: bulk_session_action_props(sessions),
            sessions: sessions,
          }
        end

        def session_columns
          %i(device last_activity created expires_at status action).index_with do |column|
            t("base.shared.identity.sessions.columns.#{column}")
          end
        end

        def bulk_session_action_props(sessions)
          return unless sessions.any? { |session| session.fetch(:revoke).present? }

          {
            others: {
              label: t("sign.app.settings.sessions.revoke.others_button"),
              href: base_com_identity_other_sessions_path(ri: params[:ri]),
              confirm: t("base.com.identity.sessions.index.revoke_others_confirm"),
            },
          }
        end

        def serialize_session_row(session)
          row = ::Base::Identity::SessionPresenter.new.present(
            session, current: current_session_record?(session), surface: :com,
          )
          row[:revoke] = session_revoke_action(session)
          row
        end

        def session_revoke_action(session)
          return if current_session_record?(session)

          {
            label: t("base.shared.identity.sessions.revoke"),
            href: base_com_identity_session_path(session.public_id, ri: params[:ri]),
            confirm: t("base.com.identity.sessions.index.revoke_confirm"),
          }
        end

        def visible_sessions = current_visitor.visitor_tokens.session_inventory

        def set_session = @session = visible_sessions.find_by!(public_id: params.expect(:id))

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
