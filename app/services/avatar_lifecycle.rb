# typed: false
# frozen_string_literal: true

module AvatarLifecycle
  class Error < StandardError; end

  class InvalidTransition < Error; end

  class UnauthorizedTransition < Error; end

  class Transition < ApplicationService
    TRANSITIONS = {
      "active" => %w(suspended archived banned deleted),
      "suspended" => %w(active banned deleted),
      "archived" => %w(active banned deleted),
      "banned" => %w(deleted),
      "deleted" => [],
    }.freeze

    PRIVILEGED_ACTOR_TYPES = %w(admin moderator system).freeze
    OWNER_ACTOR_TYPES = %w(owner admin moderator system).freeze

    attr_reader :avatar, :to_state_key, :changed_by_type, :changed_by_public_id, :reason, :metadata

    def initialize(avatar:, to_state_key:, changed_by_type:, changed_by_public_id:, reason:, metadata: {})
      super()
      @avatar = avatar
      @to_state_key = to_state_key.to_s
      @changed_by_type = changed_by_type.to_s
      @changed_by_public_id = changed_by_public_id
      @reason = reason
      @metadata = metadata
    end

    def call
      Avatar.transaction do
        locked_avatar = Avatar.lock.find(avatar.id)
        from_state = AvatarLifecycleState.find(locked_avatar.lifecycle_state_id)
        to_state = AvatarLifecycleState.find_by!(key: to_state_key)

        validate_transition!(from_state.key, to_state.key)
        validate_actor!(from_state.key, to_state.key)

        locked_avatar.update!(lifecycle_state: to_state)
        locked_avatar.avatar_lifecycle_events.create!(
          from_state_key: from_state.key,
          to_state_key: to_state.key,
          changed_by_type: changed_by_type,
          changed_by_public_id: changed_by_public_id,
          reason: reason,
          metadata: metadata,
        )
        locked_avatar
      end
    end

    private

    def validate_transition!(from_state_key, requested_to_state_key)
      allowed_targets =
        TRANSITIONS.fetch(from_state_key) do
          raise InvalidTransition, "unsupported avatar lifecycle state: #{from_state_key.inspect}"
        end

      return if allowed_targets.include?(requested_to_state_key)

      raise InvalidTransition,
            "avatar lifecycle transition #{from_state_key.inspect} -> #{requested_to_state_key.inspect} is not allowed"
    end

    def validate_actor!(from_state_key, requested_to_state_key)
      return if privileged_actor?
      return if owner_actor? && owner_transition_allowed?(from_state_key, requested_to_state_key)

      raise UnauthorizedTransition,
            "actor #{changed_by_type.inspect} cannot transition avatar lifecycle " \
            "#{from_state_key.inspect} -> #{requested_to_state_key.inspect}"
    end

    def privileged_actor?
      PRIVILEGED_ACTOR_TYPES.include?(changed_by_type)
    end

    def owner_actor?
      OWNER_ACTOR_TYPES.include?(changed_by_type)
    end

    def owner_transition_allowed?(from_state_key, requested_to_state_key)
      case [from_state_key, requested_to_state_key]
      when ["active", "archived"], ["archived", "active"], ["active", "deleted"], ["archived", "deleted"]
        true
      else
        false
      end
    end
  end
end
