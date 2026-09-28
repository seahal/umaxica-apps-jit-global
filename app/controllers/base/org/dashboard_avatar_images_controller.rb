# typed: false
# frozen_string_literal: true

module Base
  module Org
    # Streams the image of the Avatar in the session's current selection from private storage.
    # The identity comes only from the session selection; the `v` query parameter is a cache
    # buster and never selects anything. See adr/base-dashboard-avatar-image-delivery.md.
    class DashboardAvatarImagesController < Base::Org::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      skip_before_action :set_preferences_cookie

      public

      def show
        # org Avatars are optional: no Avatar, or an Avatar without an image, is a normal absence.
        avatar = switcher.selected_avatar
        authorize!(avatar || Avatar, to: avatar ? :show? : :index?)
        return head(:not_found) if avatar.nil?

        attachment = avatar.image
        return head(:not_found) if attachment.nil?

        mime_type = attachment.mime_type.to_s
        raise RuntimeError, "stored Avatar image has an unsupported type" unless
          AvatarImageUploader::ALLOWED_MIME_TYPES.include?(mime_type)

        # An ETag with public: false yields "max-age=0, private, must-revalidate": every use
        # revalidates and no shared cache stores it.
        return unless stale?(etag: avatar.image_cache_key, public: false)

        send_data(attachment.read, type: mime_type, disposition: "inline")
      end

      protected

      def track_authenticated_session_activity?
        return false if request.get? || request.head?

        super
      end

      private

      def switcher
        @switcher ||= BaseSwitcherAuthority.new(
          surface: :org, principal: current_operator, session: current_session,
        )
      end
    end
  end
end
