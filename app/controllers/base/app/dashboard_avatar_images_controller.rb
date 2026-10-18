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

      skip_before_action :set_preferences_cookie

      public

      # R5-WU14: the image comes from the Avatar owner; this RP only applies its cache validation.
      def show
        status, body, mime_type, cache_key =
          AvatarAuthorityClient.new(
            surface: "app",
            access_token: BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE),
            persona: Actor.selection.account_public_id,
          ).selected_image
        authorize!(
          AvatarAuthorityClient::Result.new(status:, data: {}, errors: {}), to: :relay?,
                                                                            with: AvatarRemoteResultPolicy,
        )
        case status
        when :ok
          raise RuntimeError, "stored Avatar image has an unsupported type" unless
            AvatarImageUploader::ALLOWED_MIME_TYPES.include?(mime_type.to_s)

          # An ETag with public: false yields "max-age=0, private, must-revalidate".
          send_data(body, type: mime_type, disposition: "inline") if stale?(etag: cache_key, public: false)
        when :no_image then send_default_image
        when :not_found then head(:not_found)
        when :forbidden then head(:forbidden)
        else head(:service_unavailable)
        end
      end

      protected

      def track_authenticated_session_activity?
        return false if request.get? || request.head?

        super
      end

      private

      def render_browser_rp_unauthenticated!
        response.set_header("Cache-Control", "no-store")
        return render(json: { error: "unauthorized" }, status: :unauthorized) if request.format.json?

        head :unauthorized
      end

      def send_default_image
        # An ETag with public: false yields "max-age=0, private, must-revalidate": every use
        # revalidates and no shared cache stores it.
        return unless stale?(etag: DEFAULT_IMAGE_ETAG, public: false)

        send_file(DEFAULT_IMAGE_PATH, type: "image/png", disposition: "inline")
      end
    end
  end
end
