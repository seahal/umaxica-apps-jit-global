# typed: false
# frozen_string_literal: true

module Base
  module App
    module Organizations
      class MembershipsController < Base::App::ApplicationController
        include ::SurfaceInertiaPage

        include ::BaseMembershipRelay

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        MEMBERSHIP_SURFACE = "app"

        public

        def index
          result = membership_result!(membership_authority.memberships(org_ref))
          return unless result

          respond_to do |format|
            format.json { render json: [] }
            format.html { render inertia: true, props: membership_index_props(result.data) }
          end
        end

        def show
          result = membership_result!(membership_authority.membership(org_ref, membership_id))
          return unless result

          respond_to do |format|
            format.json { render json: {} }
            format.html do
              render inertia: true, props: {
                title: t("base.app.navigation.membership", id: membership_id),
                body: t("base.app.navigation.membership_unavailable"),
                up_link: membership_index_link,
                action_link: result.data["can_edit"] ? {
                  label: t("actions.edit"),
                  href: edit_base_app_organization_membership_path(org_ref, membership_id, ri: params[:ri]),
                } : nil,
              }
            end
          end
        end

        def new
          return unless decide!("new?")

          render inertia: true, props: {
            title: t("base.app.navigation.new_membership"),
            body: t("base.app.navigation.membership_unavailable"),
            up_link: membership_index_link,
          }
        end

        def edit
          return unless decide!("edit?", id: membership_id)

          render inertia: true, props: {
            title: t("base.app.navigation.edit_membership", id: membership_id),
            body: t("base.app.navigation.membership_unavailable"),
            up_link: {
              label: t("actions.up"),
              href: base_app_organization_membership_path(org_ref, membership_id, ri: params[:ri]),
            },
          }
        end

        def create
          head(:unprocessable_content) if decide!("create?")
        end

        def update
          head(:unprocessable_content) if decide!("update?", id: membership_id)
        end

        def destroy
          head(:no_content) if decide!("destroy?", id: membership_id)
        end

        private

        def org_ref = params.expect(:organization_id)

        def membership_id = params.expect(:id)

        def decide!(rule, id: nil)
          membership_result!(membership_authority.authorization(org_ref, rule, id:))
        end

        def membership_index_link
          { label: t("actions.up"), href: base_app_organization_memberships_path(org_ref, ri: params[:ri]) }
        end

        def membership_index_props(data)
          {
            title: t("base.app.navigation.memberships"),
            body: t("base.app.navigation.membership_unavailable"),
            empty: t("base.app.navigation.memberships_empty"),
            up_link: { label: t("actions.up"), href: base_app_organization_path(org_ref, ri: params[:ri]) },
            create_action: data.fetch("can_new") ? {
              label: t("base.app.navigation.new_membership"),
              href: new_base_app_organization_membership_path(org_ref, ri: params[:ri]),
            } : nil,
            entries: data.fetch("memberships").map { |membership|
              id = membership.fetch("id")
              { public_id: id.to_s,
                label: t("base.app.navigation.membership", id:),
                href: base_app_organization_membership_path(org_ref, id, ri: params[:ri]), }
            },
          }
        end
      end
    end
  end
end
