# typed: false
# frozen_string_literal: true

module Base
  module App
    module Api
      module V0
        module Avatar
          # Avatar owner endpoints for the app Base Self-RP (R5-WU14). Same rules as the former
          # in-process pages: AvatarPolicy, persona binding, ownership period and membership lock.
          class AvatarsController < ActionController::API
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
            # A denial at the locked write (membership changed after the policy check) is distinct from
            # a policy refusal, so the RP keeps answering it as 403 exactly as before.
            rescue_from AvatarOwnerMembershipLockService::AuthorizationDenied, with: :render_owner_denied
            rescue_from AvatarProvisioning::Create::Unauthorized, with: :render_owner_denied

            public

            def index
              authorize!(::Avatar, to: :index?)
              render json: {
                avatars: avatar_switcher.available_avatars.map { |avatar| summary(avatar) },
                can_create: !AvatarPersonaBinding.active.exists?(persona: persona_record),
              }
            end

            def show
              avatar = find_avatar!
              authorize!(avatar, to: :show?)
              handle = Handle.find_by(id: avatar.active_handle_id)&.handle
              render json: { avatar: summary(avatar).merge(handle:) }
            end

            def create
              authorize!(::Avatar, to: :create?)
              permitted = params.fetch(:avatar, {}).permit(:moniker, :handle)
              result = AvatarProvisioning::Create.call(
                actor: avatar_actor, subject_type: :persona, subject: persona_record,
                avatar_params: permitted.except(:handle), handle_params: permitted.slice(:handle),
                owner_surface: "app", owner_collective_public_id: avatar_root.try(:selected_collective_public_id),
              )
              return render(
                json: { avatar: summary(created_avatar(result.avatar)) }, status: :created,
              ) if result.success?

              error = result.errors.fetch(0)
              raise error unless error.is_a?(ActiveRecord::RecordInvalid)

              render json: { errors: creation_errors(error.record) }, status: :unprocessable_content
            end

            def update
              avatar = find_avatar!
              authorize!(avatar, to: :update?)
              observed = avatar.current_ownership_period || raise(ActiveRecord::RecordNotFound)
              raise AvatarOwnerMembershipLockService::AuthorizationDenied unless observed.owner_surface == "app"

              moniker = params.fetch(:avatar, {}).permit(:moniker)[:moniker]
              result =
                AvatarOwnerMembershipLockService.call(
                  actor: avatar_actor, surface: "app", subject_public_id: persona_record.public_id,
                  owner_collective_public_id: observed.owner_collective_public_id, permission: "avatar.update",
                ) do
                  ::Avatar.transaction do
                    current = AvatarOwnershipPeriodSource.current_for(avatar, lock: true)
                    unless [current.owner_surface, current.owner_collective_public_id] ==
                        [observed.owner_surface, observed.owner_collective_public_id]
                      raise AvatarOwnerMembershipLockService::AuthorizationDenied, "Avatar owner changed"
                    end

                    AvatarMonikerWriterOperation.call(avatar:, moniker:, expected_current: :present)
                  end
                end
              return render(json: { avatar: summary(find_avatar!) }) if result.success?

              render json: { errors: serialize_errors(result.errors) }, status: :unprocessable_content
            end

            private

            def find_avatar! = avatar_switcher.find_avatar(params[:avatar_ref]) || raise(ActiveRecord::RecordNotFound)

            def persona_record = @persona_record ||= ClientPersona.find_by!(public_id: params.expect(:persona))

            # Re-read through the switcher so the moniker association is preloaded.
            def created_avatar(avatar) = avatar_switcher.find_avatar(avatar.public_id) || avatar

            def summary(avatar)
              moniker = avatar.current_avatar_moniker || raise(ActiveRecord::RecordNotFound)
              { public_id: avatar.public_id, moniker: moniker.moniker }
            end

            def serialize_errors(errors)
              errors.transform_keys { |attribute| "avatar.#{attribute}" }.transform_values { |messages| messages.first }
            end

            # One active Avatar per persona: that conflict is reported under the form's own key.
            def creation_errors(record)
              errors = serialize_errors(record.errors.to_hash.slice(:moniker, :handle))
              errors["avatar"] = I18n.t("base.app.avatars.already_assigned") if record.errors.of_kind?(
                :persona_id,
                :taken,
              )
              errors
            end
          end
        end
      end
    end
  end
end
