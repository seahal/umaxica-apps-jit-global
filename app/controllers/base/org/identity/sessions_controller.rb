# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      class SessionsController < ::Base::Org::ApplicationController
        include ::SurfaceInertiaPage
        include ::SessionTimestampHelper

        AUTHENTICATION_MODE = :private

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
            title: t(".page_title"),
            heading: "Auth::Org::Setting::Sessions#show",
            body: "Find me in app/views/sign/org/setting/sessions/show.html.erb",
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
            title: "Sessions",
            back_link: {
              label: t("sign.org.settings.show.back"),
              href: base_org_identity_path(ri: params[:ri]),
            },
            empty_message: t("base.org.identity.sessions.index.empty_message"),
            columns: {
              session: "Session",
              kind: "Kind",
              binding: "Binding",
              last_activity: "Last activity",
              created: "Created",
              refresh_expires: "Refresh expires",
            },
            # The bulk revocations are offered only when another session exists to revoke, exactly
            # as the ERB decided before rendering them.
            bulk_revocations: (sessions.any? { |session| !session.fetch(:current) }) ? bulk_revocations : nil,
            sessions: sessions,
          }
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
          current = current_session_record?(session)

          {
            public_id: session.public_id,
            current: current,
            current_label: current ? "current" : nil,
            status: session.staff_token_status_id,
            kind: session.staff_token_kind_id,
            binding: session.dbsc_enabled? ? "DBSC" : "NORMAL",
            last_activity: localized_session_timestamp(session.last_used_at || session.created_at),
            created: localized_session_timestamp(session.created_at),
            refresh_expires: localized_session_timestamp(session.discarded_at),
            # The current session cannot revoke itself here, so no revoke action is sent for it.
            revoke: current ? nil : session_revocation(session),
          }
        end

        def session_revocation(session)
          {
            label: "Revoke",
            href: base_org_identity_session_path(session.public_id, ri: params[:ri]),
            confirm: t("base.org.identity.sessions.index.revoke_confirm"),
          }
        end

        def visible_sessions
          current_operator.staff_tokens.session_inventory
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
