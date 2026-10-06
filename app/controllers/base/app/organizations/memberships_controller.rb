# typed: false
# frozen_string_literal: true

module Base
  module App
    module Organizations
      class MembershipsController < Base::App::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :set_organization
        before_action :set_membership, only: %i(show edit update destroy)

        public

        def index
          authorize!(@organization, to: :index?, with: OrganizationMembershipPolicy)
          respond_to do |format|
            format.json { render json: [] }
            format.html { render inertia: true, props: membership_index_props }
          end
        end

        def show
          authorize!(@membership, to: :show?, with: OrganizationMembershipPolicy)
          respond_to do |format|
            format.json { render json: {} }
            format.html do
              render inertia: true, props: {
                title: t("base.app.navigation.membership", id: @membership.id),
                body: t("base.app.navigation.membership_unavailable"),
                up_link: membership_index_link,
                action_link: allowed_to?(:edit?, @membership, with: OrganizationMembershipPolicy) ? {
                  label: t("actions.edit"),
                  href: edit_base_app_organization_membership_path(
                    @organization.public_id, @membership.id,
                    ri: params[:ri],
                  ),
                } : nil,
              }
            end
          end
        end

        def new
          authorize!(@organization, to: :new?, with: OrganizationMembershipPolicy)
          render inertia: true, props: {
            title: t("base.app.navigation.new_membership"),
            body: t("base.app.navigation.membership_unavailable"),
            up_link: membership_index_link,
          }
        end

        def edit
          authorize!(@membership, to: :edit?, with: OrganizationMembershipPolicy)
          render inertia: true, props: {
            title: t("base.app.navigation.edit_membership", id: @membership.id),
            body: t("base.app.navigation.membership_unavailable"),
            up_link: {
              label: t("actions.up"),
              href: base_app_organization_membership_path(@organization.public_id, @membership.id, ri: params[:ri]),
            },
          }
        end

        def create
          authorize!(@organization, to: :create?, with: OrganizationMembershipPolicy)
          head :unprocessable_content
        end

        def update
          authorize!(@membership, to: :update?, with: OrganizationMembershipPolicy)
          head :unprocessable_content
        end

        def destroy
          authorize!(@membership, to: :destroy?, with: OrganizationMembershipPolicy)
          head :no_content
        end

        private

        def membership_index_link
          { label: t("actions.up"),
            href: base_app_organization_memberships_path(@organization.public_id, ri: params[:ri]), }
        end

        def membership_index_props
          memberships =
            @organization.persona_memberships.order(:id).select do |membership|
              allowed_to?(:show?, membership, with: OrganizationMembershipPolicy)
            end
          {
            title: t("base.app.navigation.memberships"),
            body: t("base.app.navigation.membership_unavailable"),
            empty: t("base.app.navigation.memberships_empty"),
            up_link: { label: t("actions.up"),
                       href: base_app_organization_path(@organization.public_id, ri: params[:ri]), },
            create_action: allowed_to?(:new?, @organization, with: OrganizationMembershipPolicy) ? {
              label: t("base.app.navigation.new_membership"),
              href: new_base_app_organization_membership_path(@organization.public_id, ri: params[:ri]),
            } : nil,
            entries: memberships.map { |membership|
              { public_id: membership.id.to_s,
                label: t("base.app.navigation.membership", id: membership.id),
                href: base_app_organization_membership_path(@organization.public_id, membership.id, ri: params[:ri]), }
            },
          }
        end

        def set_organization
          @organization = Enterprise.find_by!(public_id: params.expect(:organization_id))
        end

        def set_membership
          @membership = @organization.persona_memberships.find(params.expect(:id))
        end
      end
    end
  end
end
