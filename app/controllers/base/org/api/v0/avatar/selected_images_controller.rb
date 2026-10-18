# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Api
      module V0
        module Avatar
          # The selected Avatar's stored image for the org Base Self-RP dashboard (R5-WU14; image
          # bytes through the Avatar API approved 2026-10-17). 200 = image bytes with the cache key
          # in X-Avatar-Image-Key; 204 = the Avatar has no stored image; 404 = no selected Avatar.
          class SelectedImagesController < ActionController::API
            include ::DefaultNoStore

            prepend_before_action :apply_default_no_store
            include ActionPolicy::Controller
            include ::ActorSupport
            include ::AvatarAuthorityApiEndpoint

            AUTHENTICATION_MODE = :open
            AVATAR_SURFACE = "org"

            authorize :user, through: :avatar_actor
            around_action :with_actor_lifecycle
            before_action :authenticate_avatar_caller!
            before_action :set_current_actor
            before_action :verify_avatar_persona!
            rescue_from ActionPolicy::Unauthorized, with: :render_forbidden
            rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
            rescue_from ActionController::ParameterMissing, with: :render_bad_request

            public

            def show
              avatar = avatar_switcher.selected_avatar || nil
              authorize!(avatar || ::Avatar, to: avatar ? :show? : :index?)
              return head(:not_found) if avatar.nil?

              attachment = avatar.image
              return head(:no_content) if attachment.nil?

              mime_type = attachment.mime_type.to_s
              raise RuntimeError, "stored Avatar image has an unsupported type" unless
                AvatarImageUploader::ALLOWED_MIME_TYPES.include?(mime_type)

              response.set_header("X-Avatar-Image-Key", avatar.image_cache_key.to_s)
              send_data(attachment.read, type: mime_type, disposition: "inline")
            end
          end
        end
      end
    end
  end
end
