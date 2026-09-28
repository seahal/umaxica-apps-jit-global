# typed: false
# frozen_string_literal: true

module Base
  module App
    # Streams the image of the Avatar in the session's current selection from private storage.
    # The identity comes only from the session selection; the `v` query parameter is a cache
    # buster and never selects anything. See adr/base-dashboard-avatar-image-delivery.md.
    class DashboardAvatarImagesController < Base::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      DEFAULT_IMAGE_PATH = Rails.root.join("app/assets/images/base/default_avatar.png").freeze
      DEFAULT_IMAGE_ETAG = "base-default-avatar-v1"

      before_action :authenticate_client!
      skip_before_action :set_preferences_cookie

      public

      def show
        # The app surface requires an Avatar, so a valid selection without one is a broken invariant.
        avatar = switcher.selected_avatar || raise(RuntimeError, "selected app context has no Avatar")
        authorize!(avatar, to: :show?)

        attachment = avatar.image
        return send_default_image if attachment.nil?

        send_stored_image(avatar, attachment)
      end

      protected

      def track_authenticated_session_activity?
        return false if request.get? || request.head?

        super
      end

      private

      def send_default_image
        # An ETag with public: false yields "max-age=0, private, must-revalidate": every use
        # revalidates and no shared cache stores it.
        return unless stale?(etag: DEFAULT_IMAGE_ETAG, public: false)

        send_file(DEFAULT_IMAGE_PATH, type: "image/png", disposition: "inline")
      end

      def send_stored_image(avatar, attachment)
        mime_type = attachment.mime_type.to_s
        raise RuntimeError, "stored Avatar image has an unsupported type" unless
          AvatarImageUploader::ALLOWED_MIME_TYPES.include?(mime_type)

        # An ETag with public: false yields "max-age=0, private, must-revalidate": every use
        # revalidates and no shared cache stores it.
        return unless stale?(etag: avatar.image_cache_key, public: false)

        send_data(attachment.read, type: mime_type, disposition: "inline")
      end

      def switcher
        @switcher ||= BaseSwitcherAuthority.new(
          surface: :app, principal: current_client, session: current_session,
        )
      end
    end
  end
end
