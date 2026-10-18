# typed: false
# frozen_string_literal: true

module Base
  module Org
    # adr/operator-capability-authorization.md, IAM landing page.
    class IamController < Base::Org::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def index
        authorize!(:org_console, to: :iam?, with: OrgConsolePolicy)
        response.headers["Cache-Control"] = "private, no-store"
        render inertia: "base/org/iam/index",
               props: {
                 title: t("base.org.admin.iam.title"),
                 description: t("base.org.admin.iam.description"),
                 up_link: dashboard_up_link,
                 sections: [
                   {
                     heading: t("base.org.admin.iam.areas"),
                     items: [{ label: t("base.org.admin.grants.title"), href: base_org_iam_grants_path }],
                   },
                 ],
               }
      end
    end
  end
end
