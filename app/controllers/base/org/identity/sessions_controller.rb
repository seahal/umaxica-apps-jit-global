# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      class SessionsController < ::Base::Org::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_operator!
        before_action :set_session, only: %i(show destroy)

        def index
          authorize!(OperatorToken, to: :index?)
          @sessions = visible_sessions.order(created_at: :desc)
          render inertia: true, props: index_page_props
        end

        def show
          authorize!(@session)
          render inertia: true, props: {
            title: t("base.shared.identity.sessions.title"),
            back_link: { label: t("sign.org.settings.show.back"), href: base_org_identity_sessions_path(ri: params[:ri]) },
            expires_at_description: t("base.shared.identity.sessions.expires_at_description"),
            session: serialize_session(@session),
            columns: session_columns,
          }
        end

        def destroy
          authorize!(@session)
          revoke_selected_session!(@session) unless current_session_record?(@session)
          redirect_to(base_org_identity_sessions_path(ri: params[:ri]), status: :see_other)
        end

        private

        def index_page_props
          sessions = @sessions.map { |session| serialize_session(session) }
          {
            title: t("base.shared.identity.sessions.title"),
            back_link: {
              label: t("sign.org.settings.show.back"),
              href: base_org_identity_path(ri: params[:ri]),
            },
            empty_message: t("base.shared.identity.sessions.empty"),
            expires_at_description: t("base.shared.identity.sessions.expires_at_description"),
            columns: session_columns,
            bulk_revocations: (sessions.any? { |session| session[:revoke] }) ? bulk_revocations : nil,
            sessions: sessions,
          }
        end

        def session_columns
          %i(device last_activity created expires_at status mode action).index_with do |column|
            t("base.shared.identity.sessions.columns.#{column}")
          end
        end

        def bulk_revocations
          {
            others: {
              label: t("sign.org.settings.sessions.revoke.others_button"),
              href: base_org_identity_other_sessions_path(ri: params[:ri]),
              confirm: t("sign.org.settings.sessions.revoke.others_confirm"),
            },
          }
        end

        def serialize_session(session)
          row = ::Base::Identity::SessionPresenter.new.present(
            session, current: current_session_record?(session), surface: :org,
          )
          row[:revoke] = session_revoke_action(session)
          row
        end

        def session_revoke_action(session)
          return if current_session_record?(session)

          {
            label: t("base.shared.identity.sessions.revoke"),
            href: base_org_identity_session_path(session.public_id, ri: params[:ri]),
            confirm: t("base.org.identity.sessions.index.revoke_confirm"),
          }
        end

        def visible_sessions = current_operator.staff_tokens.session_inventory

        def set_session = @session = visible_sessions.find_by!(public_id: params.expect(:id))

        def current_session_record?(session)
          return false unless session

          session.id == current_session&.id ||
            session.public_id == current_session_public_id ||
            (session.device_session_id.present? && session.device_session_id == current_session&.device_session_id)
        end

        def revoke_selected_session!(session)
          AuthenticationSelectedSessionRevoker.call(
            owner: current_operator,
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
