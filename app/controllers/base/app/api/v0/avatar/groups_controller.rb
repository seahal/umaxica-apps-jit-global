# typed: false
# frozen_string_literal: true

module Base
  module App
    module Api
      module V0
        module Avatar
          # Avatar owner endpoint for the app Base Self-RP (R5-WU14), moved from the former in-process
          # page with the same policy, relation scope and GroupManagement/GroupAvatarMemberships rules.
          class GroupsController < ActionController::API
            include ::DefaultNoStore

            prepend_before_action :apply_default_no_store
            include ActionPolicy::Controller
            include ::ActorSupport
            include ::AvatarAuthorityApiEndpoint

            AUTHENTICATION_MODE = :open
            AVATAR_SURFACE = "app"

            authorize :user, through: :avatar_actor
            around_action :with_actor_lifecycle
            before_action :authenticate_avatar_caller!
            before_action :set_current_actor
            before_action :verify_avatar_persona!
            rescue_from ActionPolicy::Unauthorized, with: :render_forbidden
            rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
            rescue_from ActionController::ParameterMissing, with: :render_bad_request

            rescue_from AvatarOwnerMembershipLockService::AuthorizationDenied, with: :forbid_owner_mutation

            before_action :set_group, only: %i(show update destroy)
            # Collection visibility comes from ::AvatarGroupPolicy's relation scope; fail if index stops using it.
            verify_authorized_scoped only: :index

            public

            def index
              authorize!(::AvatarGroup, to: :index?)
              groups = authorized_scope(::AvatarGroup.all).order(:created_at, :id)
              render json: { groups: groups.map { |group| serialize_group(group) } }
            end

            def show
              authorize!(@group, to: :show?)
              render json: { group: serialize_group(@group) }
            end

            def create
              authorize!(::AvatarGroup, to: :create?)
              group = GroupManagement::Create.call(
                account_surface: "app",
                account_public_id: Actor.selection.account_public_id,
                owner_surface: "app",
                owner_collective_public_id: Actor.selection.collective_public_id,
                actor: avatar_actor,
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
                actor: avatar_actor,
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
                actor: avatar_actor,
                surface: "app",
                subject_public_id: Actor.selection.account_public_id,
                account_public_id: Actor.selection.account_public_id,
              )
              head :no_content
            end

            private

            def forbid_owner_mutation = render_owner_denied

            def set_group
              @group = ::AvatarGroup.find_by!(public_id: params.expect(:ref))
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
    end
  end
end
