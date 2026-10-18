# typed: false
# frozen_string_literal: true

module Base
  module App
    module Api
      module V0
        module Avatar
          # Avatar follow/block/mute edges for the app Base Self-RP (R5-WU14). The acting Avatar is the
          # one selected on the actor's own root; the existing edge policies and operations decide.
          class SocialEdgesController < ActionController::API
            include ::DefaultNoStore

            prepend_before_action :apply_default_no_store
            include ActionPolicy::Controller
            include ::ActorSupport
            include ::AvatarAuthorityApiEndpoint

            AUTHENTICATION_MODE = :open
            AVATAR_SURFACE = "app"
            KINDS = {
              "follows" => [AvatarFollow, AvatarFollowPolicy, :follower_avatar, :followed_avatar,
                            AvatarSocialGraph::Follow, AvatarSocialGraph::Unfollow,],
              "blocks" => [AvatarBlock, AvatarBlockPolicy, :blocker_avatar, :blocked_avatar,
                           AvatarSocialGraph::Block, AvatarSocialGraph::Unblock,],
              "mutes" => [AvatarMute, AvatarMutePolicy, :muter_avatar, :muted_avatar,
                          AvatarSocialGraph::Mute, AvatarSocialGraph::Unmute,],
            }.freeze

            around_action :with_actor_lifecycle
            before_action :authenticate_avatar_caller!
            before_action :set_current_actor
            before_action :verify_avatar_persona!
            rescue_from ActionPolicy::Unauthorized, with: :render_forbidden
            rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
            rescue_from ActionController::ParameterMissing, with: :render_bad_request

            public

            def create
              model, policy, actor_key, target_key, create_op, = kind
              record = model.new(actor_key => actor_avatar, target_key => target_avatar)
              authorize!(record, to: :create?, with: policy, context: { user: actor_avatar })
              edge = create_op.call(actor_avatar:, target_avatar:)
              render json: { public_id: edge.id.to_s }, status: :created
            end

            def destroy
              model, policy, actor_key, target_key, _, destroy_op = kind
              record = model.find_by!(actor_key => actor_avatar, target_key => target_avatar)
              authorize!(record, to: :destroy?, with: policy, context: { user: actor_avatar })
              destroy_op.call(actor_avatar:, target_avatar:)
              head :no_content
            end

            private

            def kind = KINDS.fetch(params.expect(:kind)) { raise ActionController::ParameterMissing, :kind }

            def actor_avatar = @actor_avatar ||= ::Avatar.find_by!(public_id: Actor.selection.avatar_public_id)

            def target_avatar = @target_avatar ||= ::Avatar.find_by!(public_id: params.expect(:avatar_ref))
          end
        end
      end
    end
  end
end
