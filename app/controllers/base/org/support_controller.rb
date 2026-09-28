# typed: false
# frozen_string_literal: true

module Base
  module Org
    # adr/operator-capability-authorization.md, Support. The landing page lists only the areas this
    # operator holds a capability for; every linked endpoint authorizes again on its own.
    class SupportController < Base::Org::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def index
        authorize!(:org_console, to: :support?, with: OrgConsolePolicy)
        response.headers["Cache-Control"] = "private, no-store"
        render inertia: "base/org/support/index",
               props: {
                 title: t("base.org.admin.support.title"),
                 description: t("base.org.admin.support.description"),
                 up_link: dashboard_up_link,
                 sections: [{ heading: t("base.org.admin.support.areas"), items: support_areas }],
               }
      end

      private

      def support_areas
        areas = []
        if current_operator.capability?(OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP)
          areas << { label: t("base.org.admin.support.clients"), href: base_org_support_clients_path }
        end
        if current_operator.capability?(OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM)
          areas << { label: t("base.org.admin.support.visitors"), href: base_org_support_visitors_path }
        end
        if current_operator.capability?(OperatorCapabilityGrant::ENFORCEMENT_READ_APP)
          areas << { label: t("base.org.admin.support.enforcement_app"),
                     href: base_org_support_app_enforcement_cases_path, }
        end
        if current_operator.capability?(OperatorCapabilityGrant::ENFORCEMENT_READ_COM)
          areas << { label: t("base.org.admin.support.enforcement_com"),
                     href: base_org_support_com_enforcement_cases_path, }
        end
        areas
      end
    end
  end
end
