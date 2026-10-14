# typed: false
# frozen_string_literal: true

module AvatarSocialGraph
  class Error < StandardError; end

  class SelfEdgeError < Error; end

  class BlockedError < Error; end

  class Follow < ApplicationService
    attr_reader :actor_avatar, :target_avatar

    def initialize(actor_avatar:, target_avatar:)
      super()
      @actor_avatar = actor_avatar
      @target_avatar = target_avatar
    end

    def call
      raise SelfEdgeError, "avatar cannot follow itself" if actor_avatar == target_avatar
      raise BlockedError, "actor avatar is not active" unless active_avatar?(actor_avatar)
      raise BlockedError, "target avatar is not active" unless active_avatar?(target_avatar)
      raise BlockedError, "follow blocked by target avatar" if blocked_by_target?
      raise BlockedError, "follow blocked by actor avatar" if blocked_by_actor?

      existing_follow || create_follow
    end

    private

    def blocked_by_target?
      target_avatar.outgoing_blocks.exists?(blocked_avatar_id: actor_avatar.id)
    end

    def blocked_by_actor?
      actor_avatar.outgoing_blocks.exists?(blocked_avatar_id: target_avatar.id)
    end

    def existing_follow
      actor_avatar.outgoing_follows.find_by(followed_avatar_id: target_avatar.id)
    end

    def create_follow
      actor_avatar.outgoing_follows.create!(followed_avatar: target_avatar)
    end

    def active_avatar?(avatar)
      AvatarLifecycleState.exists?(id: avatar.lifecycle_state_id, key: "active") && avatar.accessible?
    end
  end

  class Block < ApplicationService
    attr_reader :actor_avatar, :target_avatar

    def initialize(actor_avatar:, target_avatar:)
      super()
      @actor_avatar = actor_avatar
      @target_avatar = target_avatar
    end

    def call
      raise SelfEdgeError, "avatar cannot block itself" if actor_avatar == target_avatar
      raise BlockedError, "actor avatar is not active" unless active_avatar?(actor_avatar)
      raise BlockedError, "target avatar is not active" unless active_avatar?(target_avatar)

      block = existing_block || create_block
      terminate_follow(actor_avatar, target_avatar)
      terminate_follow(target_avatar, actor_avatar)
      block
    end

    private

    def existing_block
      actor_avatar.outgoing_blocks.find_by(blocked_avatar_id: target_avatar.id)
    end

    def create_block
      actor_avatar.outgoing_blocks.create!(blocked_avatar: target_avatar)
    end

    def terminate_follow(follower, followed)
      follower.outgoing_follows.where(followed_avatar_id: followed.id).destroy_all
    end

    def active_avatar?(avatar)
      AvatarLifecycleState.exists?(id: avatar.lifecycle_state_id, key: "active") && avatar.accessible?
    end
  end

  class Mute < ApplicationService
    attr_reader :actor_avatar, :target_avatar

    def initialize(actor_avatar:, target_avatar:)
      super()
      @actor_avatar = actor_avatar
      @target_avatar = target_avatar
    end

    def call
      raise SelfEdgeError, "avatar cannot mute itself" if actor_avatar == target_avatar
      raise BlockedError, "actor avatar is not active" unless active_avatar?(actor_avatar)
      raise BlockedError, "target avatar is not active" unless active_avatar?(target_avatar)

      existing_mute || create_mute
    end

    private

    def existing_mute
      actor_avatar.outgoing_mutes.find_by(muted_avatar_id: target_avatar.id)
    end

    def create_mute
      actor_avatar.outgoing_mutes.create!(muted_avatar: target_avatar)
    end

    def active_avatar?(avatar)
      AvatarLifecycleState.exists?(id: avatar.lifecycle_state_id, key: "active") && avatar.accessible?
    end
  end

  class Unfollow < ApplicationService
    attr_reader :actor_avatar, :target_avatar

    def initialize(actor_avatar:, target_avatar:)
      super()
      @actor_avatar = actor_avatar
      @target_avatar = target_avatar
    end

    def call
      existing_follow&.destroy
    end

    private

    def existing_follow
      actor_avatar.outgoing_follows.find_by(followed_avatar_id: target_avatar.id)
    end
  end

  class Unblock < ApplicationService
    attr_reader :actor_avatar, :target_avatar

    def initialize(actor_avatar:, target_avatar:)
      super()
      @actor_avatar = actor_avatar
      @target_avatar = target_avatar
    end

    def call
      existing_block&.destroy
    end

    private

    def existing_block
      actor_avatar.outgoing_blocks.find_by(blocked_avatar_id: target_avatar.id)
    end
  end

  class Unmute < ApplicationService
    attr_reader :actor_avatar, :target_avatar

    def initialize(actor_avatar:, target_avatar:)
      super()
      @actor_avatar = actor_avatar
      @target_avatar = target_avatar
    end

    def call
      existing_mute&.destroy
    end

    private

    def existing_mute
      actor_avatar.outgoing_mutes.find_by(muted_avatar_id: target_avatar.id)
    end
  end
end
