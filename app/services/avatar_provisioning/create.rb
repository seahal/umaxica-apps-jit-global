# typed: false
# frozen_string_literal: true

module AvatarProvisioning
  class Create < ApplicationService
    Result =
      Data.define(:avatar, :handle, :binding, :errors) do
        def success? = errors.empty?
      end

    Unauthorized = AvatarOwnerMembershipLockService::AuthorizationDenied

    SUPPORTED_SUBJECT_TYPES = %w(persona agent).freeze

    def initialize(actor:, subject_type:, subject:, avatar_params:, handle_params: {},
                   owner_surface:, owner_collective_public_id:)
      super()
      @actor = actor
      @subject_type = subject_type.to_s
      @subject = subject
      @avatar_params = avatar_params.to_h.symbolize_keys
      @handle_params = handle_params.to_h.symbolize_keys
      @owner_surface = owner_surface.to_s
      @owner_collective_public_id = owner_collective_public_id
    end

    def call
      validate_inputs!
      avatar = nil
      handle = nil
      binding = nil

      AvatarOwnerMembershipLockService.call(
        actor: actor,
        surface: owner_surface,
        subject_public_id: subject.public_id,
        owner_collective_public_id: owner_collective_public_id,
        permission: "avatar.update",
      ) do
        Avatar.transaction do
          ensure_reference_rows!
          handle = create_handle!
          avatar = create_avatar!(handle)
          create_ownership_period!(avatar)
          moniker_result = AvatarMonikerWriterOperation.call(
            avatar: avatar,
            moniker: avatar_params[:moniker],
            expected_current: :absent,
          )
          raise ActiveRecord::RecordInvalid.new(moniker_result.avatar_moniker) unless moniker_result.success?

          binding = create_binding!(avatar)
        end
      end

      Result.new(avatar: avatar, handle: handle, binding: binding, errors: [])
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Result.new(avatar: avatar, handle: handle, binding: binding, errors: [e])
    end

    private

    attr_reader :actor, :subject_type, :subject, :avatar_params, :handle_params,
                :owner_surface, :owner_collective_public_id

    def validate_inputs!
      raise ArgumentError, "actor is required" unless actor.is_a?(Client) || actor.is_a?(Operator)
      raise ArgumentError, "unsupported subject_type: #{subject_type.inspect}" unless
        SUPPORTED_SUBJECT_TYPES.include?(subject_type)
      raise ArgumentError, "subject is required" if subject.blank?
      raise ArgumentError, "owner_collective_public_id is required" if owner_collective_public_id.blank?

      case owner_surface
      when "app"
        raise ArgumentError, "app Avatar creation requires the selected Client Persona" unless
          actor.is_a?(Client) && subject_type == "persona" && subject.is_a?(ClientPersona) &&
            subject.client_identity.source_record_id == actor.id
      when "org"
        raise ArgumentError, "org Avatar creation requires the selected Operator Agent" unless
          actor.is_a?(Operator) && subject_type == "agent" && subject.is_a?(Agent) &&
            subject.operator_identity.source_record_id == actor.id
      else
        raise ArgumentError, "unsupported Avatar owner surface: #{owner_surface.inspect}"
      end
    end

    def ensure_reference_rows!
      HandleStatus.ensure_defaults! if HandleStatus.respond_to?(:ensure_defaults!)
      AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
      AvatarLifecycleState.find_by!(key: "active")
    end

    def create_handle!
      Handle.create!(
        handle: avatar_handle,
        handle_status_id: HandleStatus::ACTIVE,
        cooldown_until: Time.current,
        is_system: false,
      )
    end

    def create_avatar!(handle)
      Avatar.create!(
        active_handle: handle,
        capability_id: AvatarCapability::NORMAL,
        lifecycle_state: AvatarLifecycleState.find_by!(key: "active"),
      )
    end

    def create_ownership_period!(avatar)
      AvatarOwnershipStatus.find_or_create_by!(id: AvatarOwnershipStatus::ACTIVE)
      AvatarOwnershipPeriod.create!(
        avatar: avatar,
        owner_organization_id: owner_collective_public_id,
        owner_surface: owner_surface,
        owner_collective_public_id: owner_collective_public_id,
        avatar_ownership_status_id: AvatarOwnershipStatus::ACTIVE,
        valid_from: Time.current,
      )
    end

    def create_binding!(avatar)
      case subject_type
      when "persona"
        AvatarPersonaBinding.create!(avatar: avatar, persona: subject)
      when "agent"
        AvatarAgentBinding.create!(avatar: avatar, agent: subject)
      when "individual"
        AvatarIndividualBinding.create!(avatar: avatar, individual: subject)
      else
        raise ArgumentError, "unsupported subject_type: #{subject_type.inspect}"
      end
    end

    def avatar_handle
      base = handle_params[:handle].presence || avatar_params.fetch(:moniker, "")
      "#{base.to_s.parameterize.presence || "avatar"}-#{SecureRandom.alphanumeric(8).downcase}"
    end
  end
end
