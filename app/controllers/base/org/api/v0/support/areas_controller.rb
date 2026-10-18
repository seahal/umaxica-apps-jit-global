# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Api
      module V0
        module Support
          # Support landing owner for the org Base Self-RP (R5-WU17, approved WU12 pattern): the
          # operator's capabilities are read here, never in the RP cell. Every linked page
          # authorizes again on its own (adr/operator-capability-authorization.md).
          class AreasController < ActionController::API
            include ::DefaultNoStore

            prepend_before_action :apply_default_no_store
            include ActionController::MimeResponds
            include AbstractController::Translation
            include ActionPolicy::Controller
            include ::ActorSupport
            include ::AvatarAuthorityApiEndpoint
            include ::OwnerPageResponses

            AUTHENTICATION_MODE = :open
            AVATAR_SURFACE = "org"

            authorize :user, through: :avatar_actor
            around_action :with_actor_lifecycle
            before_action :authenticate_avatar_caller!
            before_action :set_current_actor
            before_action :apply_browser_context
            rescue_from ActionPolicy::Unauthorized, with: :render_forbidden

            public

            def index
              authorize!(:org_console, to: :support?, with: OrgConsolePolicy)
              render inertia: "base/org/support/index",
                     props: {
                       title: t("base.org.admin.support.title"),
                       description: t("base.org.admin.support.description"),
                       up_link: { label: t("actions.up"), href: base_org_dashboard_path(ri: params[:ri]) },
                       sections: [{ heading: t("base.org.admin.support.areas"), items: support_areas }],
                     }
            end

            private

            def support_areas
              areas = []
              if avatar_actor.capability?(OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP)
                areas << { label: t("base.org.admin.support.clients"), href: base_org_support_clients_path }
              end
              if avatar_actor.capability?(OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM)
                areas << { label: t("base.org.admin.support.visitors"), href: base_org_support_visitors_path }
              end
              if avatar_actor.capability?(OperatorCapabilityGrant::ENFORCEMENT_READ_APP)
                areas << { label: t("base.org.admin.support.enforcement_app"),
                           href: base_org_support_app_enforcement_cases_path, }
              end
              if avatar_actor.capability?(OperatorCapabilityGrant::ENFORCEMENT_READ_COM)
                areas << { label: t("base.org.admin.support.enforcement_com"),
                           href: base_org_support_com_enforcement_cases_path, }
              end
              areas
            end
          end
        end
      end
    end
  end
end
