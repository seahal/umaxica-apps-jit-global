# typed: false
# frozen_string_literal: true

module Base
  module App
    # Group resource surface for Avatar containers. Groups are not posting actors.
    class GroupsController < Base::App::FullAccessController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      rescue_from AvatarOwnerMembershipLockService::AuthorizationDenied, with: :forbid_owner_mutation

      before_action :set_group, only: %i(show update destroy)
      # Collection visibility comes from AvatarGroupPolicy's relation scope; fail if index stops using it.
      verify_authorized_scoped only: :index

      def index
        authorize!(AvatarGroup, to: :index?)
        groups = authorized_scope(AvatarGroup.all).order(:created_at, :id)
        render inertia: true, props: {
          title: "Groups",
          empty_message: t("base.app.navigation.groups_empty"),
          up_link: dashboard_up_link,
          groups: groups.map { |group|
            serialize_group(group).merge(href: base_app_group_path(group.public_id, ri: params[:ri]))
          },
        }
      end

      def show
        authorize!(@group, to: :show?)
        render json: { group: serialize_group(@group) }
      end

      def create
        authorize!(AvatarGroup, to: :create?)
        group = GroupManagement::Create.call(
          account_surface: "app",
          account_public_id: Actor.selection.account_public_id,
          owner_surface: "app",
          owner_collective_public_id: Actor.selection.collective_public_id,
          actor: current_client,
          subject_public_id: Actor.selection.account_public_id,
          name: group_params.fetch(:name),
          description: group_params[:description],
        )
        render json: { group: serialize_group(group) }, status: :created
      end

      def update
        authorize!(@group, to: :update?)
        group = GroupManagement::Update.call(
          group: @group,
          attributes: group_params,
          actor: current_client,
          surface: "app",
          subject_public_id: Actor.selection.account_public_id,
          account_public_id: Actor.selection.account_public_id,
        )
        render json: { group: serialize_group(group) }
      end

      def destroy
        authorize!(@group, to: :destroy?)
        GroupManagement::Archive.call(
          group: @group,
          actor: current_client,
          surface: "app",
          subject_public_id: Actor.selection.account_public_id,
          account_public_id: Actor.selection.account_public_id,
        )
        head :no_content
      end

      private

      def forbid_owner_mutation
        head :forbidden
      end

      def set_group
        @group = AvatarGroup.includes(:current_ownership_period).find_by!(public_id: params.expect(:id))
      end

      def group_params
        params.expect(group: [:name, :description])
      end

      def serialize_group(group)
        {
          public_id: group.public_id,
          account_surface: group.account_surface,
          account_public_id: group.account_public_id,
          name: group.name,
          description: group.description,
          state: group.state,
        }
      end
    end
  end
end
