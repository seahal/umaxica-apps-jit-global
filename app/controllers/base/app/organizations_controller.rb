# typed: false
# frozen_string_literal: true

module Base
  module App
    # Organization entity management for the app surface. Plural CRUD over the organizations the
    # signed-in client has a membership in; changing the *current* organization is the switcher's
    # job. Requires a selected actor context (FullAccessController).
    class OrganizationsController < Base::App::FullAccessController
      include ::SurfaceInertiaPage

      include ::BaseMembershipRelay

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      MEMBERSHIP_SURFACE = "app"

      public

      # R5-WU15: listed, authorized and summarized by the owner over HTTPS.
      def index
        result = membership_result!(membership_authority.organizations)
        return unless result

        render inertia: true, props: {
          title: "Organizations",
          body: "organizations",
          empty: "None available",
          entries: result.data.fetch("organizations").map { |row| serialize_organization(row.fetch("public_id")) },
          create_action: { label: "Create Organization" },
          up_link: dashboard_up_link,
        }
      end

      def show
        result = membership_result!(membership_authority.organization(params.expect(:id)))
        return unless result

        render inertia: true, props: {
          title: "Organization",
          body: "organization",
          up_link: { label: t("actions.up"), href: base_app_organizations_path(ri: params[:ri]) },
          links: organization_membership_links(params.expect(:id), result.data.fetch("memberships")),
        }
      end

      private

      def organization_membership_links(org_ref, summary)
        return [] unless summary.fetch("can_index")

        links = [{ label: t("base.app.navigation.memberships"),
                   href: base_app_organization_memberships_path(org_ref, ri: params[:ri]), }]
        if summary.fetch("can_new")
          links << { label: t("base.app.navigation.new_membership"),
                     href: new_base_app_organization_membership_path(org_ref, ri: params[:ri]), }
        end
        summary.fetch("entries").each do |entry|
          id = entry.fetch("id")
          links << { label: t("base.app.navigation.membership", id:),
                     href: base_app_organization_membership_path(org_ref, id, ri: params[:ri]), }
          next unless entry.fetch("can_edit")

          links << { label: t("base.app.navigation.edit_membership", id:),
                     href: edit_base_app_organization_membership_path(org_ref, id, ri: params[:ri]), }
        end
        links
      end

      def serialize_organization(public_id)
        { public_id:, label: public_id, href: base_app_organization_path(public_id, ri: params[:ri]) }
      end
    end
  end
end
