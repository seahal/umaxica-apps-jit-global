# typed: false
# frozen_string_literal: true

module Base
  module App
    # Group Avatar memberships; decided and written by the Avatar owner (R5-WU14).
    class GroupAvatarMembershipsController < Base::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      public

      def create
        result = relay!(avatar_authority.attach_avatar(params.expect(:group_id), membership_params.to_h))
        render(json: result.data, status: :created) if result
      end

      def update
        result = relay!(
          avatar_authority.reorder_avatar(
            params.expect(:group_id), params.expect(:id),
            membership_params.to_h,
          ),
        )
        render(json: result.data) if result
      end

      def destroy
        head(:no_content) if relay!(avatar_authority.detach_avatar(params.expect(:group_id), params.expect(:id)))
      end

      private

      # R5-WU14: the Avatar owner decides and writes; this Base Self-RP relays its answer.
      def avatar_authority
        @avatar_authority ||= AvatarAuthorityClient.new(
          surface: "app",
          access_token: BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE),
          persona: Actor.selection.account_public_id,
        )
      end

      # Owner-lock denials stay 403 as before; policy refusals go through the authorization handler.
      def relay!(result)
        if result.status == :forbidden && result.data.to_h["error"] == "owner_denied"
          authorize!(result, to: :relay?, with: AvatarRemoteResultPolicy)
          head :forbidden
          return
        end
        authorize!(result, to: :show?, with: AvatarRemoteResultPolicy)
        raise ActiveRecord::RecordNotFound, "not found" if result.status == :not_found
        return head(:service_unavailable) if result.status == :dependency
        return head(:unprocessable_content) if result.status == :unprocessable

        result
      end

      def membership_params
        params.expect(membership: %i(avatar_public_id position))
      end
    end
  end
end
