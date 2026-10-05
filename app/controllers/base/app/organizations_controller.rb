# typed: false
# frozen_string_literal: true

module Base
  module App
    # Organization entity management for the app surface. Plural CRUD over the organizations the
    # signed-in client has a membership in; changing the *current* organization is the switcher's
    # job. Requires a selected actor context (FullAccessController).
    class OrganizationsController < Base::App::FullAccessController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def index
        authorize!(current_client, to: :show?)
        organizations = switcher.available_organizations

        render inertia: true, props: {
          title: "Organizations",
          body: "organizations",
          empty: "None available",
          entries: organizations.map { |organization| serialize_organization(organization) },
          create_action: { label: "Create Organization" },
          up_link: dashboard_up_link,
        }
      end

      def show
        organization = find_organization!
        authorize!(organization, to: :show?, with: OrganizationPolicy)

        render inertia: true, props: {
          title: "Organization",
          body: "organization",
          up_link: { label: t("actions.up"), href: base_app_organizations_path(ri: params[:ri]) },
          links: organization_membership_links(organization),
        }
      end

      private

      def organization_membership_links(organization)
        return [] unless allowed_to?(:index?, organization, with: OrganizationMembershipPolicy)

        links = [{ label: t("base.app.navigation.memberships"),
                   href: base_app_organization_memberships_path(organization.public_id, ri: params[:ri]), }]
        if allowed_to?(:new?, organization, with: OrganizationMembershipPolicy)
          links << { label: t("base.app.navigation.new_membership"),
                     href: new_base_app_organization_membership_path(organization.public_id, ri: params[:ri]), }
        end
        organization.persona_memberships.order(:id).each do |membership|
          next unless allowed_to?(:show?, membership, with: OrganizationMembershipPolicy)

          links << { label: t("base.app.navigation.membership", id: membership.id),
                     href: base_app_organization_membership_path(
                       organization.public_id, membership.id,
                       ri: params[:ri],
                     ), }
          if allowed_to?(:edit?, membership, with: OrganizationMembershipPolicy)
            links << { label: t("base.app.navigation.edit_membership", id: membership.id),
                       href: edit_base_app_organization_membership_path(
                         organization.public_id, membership.id,
                         ri: params[:ri],
                       ), }
          end
        end
        links
      end

      def serialize_organization(organization)
        {
          public_id: organization.public_id,
          label: organization.public_id,
          href: base_app_organization_path(organization.public_id, ri: params[:ri]),
        }
      end

      # Scoped to the organizations the principal is a member of: a foreign or non-existent id
      # raises RecordNotFound (404), the authoritative membership gate for show/edit/update.
      def find_organization!
        switcher.find_organization(params.expect(:id)) || raise(ActiveRecord::RecordNotFound)
      end

      def switcher
        @switcher ||= BaseSwitcherAuthority.new(
          surface: :app, principal: current_client, session: current_session,
        )
      end
    end
  end
end
