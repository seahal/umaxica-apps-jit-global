# typed: false
# frozen_string_literal: true

module Base
  module App
    # Group resource surface for Avatar containers. Groups are not posting actors. Reads and writes
    # go to the Avatar owner (R5-WU14).
    class GroupsController < Base::App::FullAccessController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      public

      def index
        result = relay!(avatar_authority.groups)
        return unless result

        render inertia: true, props: {
          title: "Groups",
          empty_message: t("base.app.navigation.groups_empty"),
          up_link: dashboard_up_link,
          groups: result.data.fetch("groups").map { |group|
            group.merge("href" => base_app_group_path(group.fetch("public_id"), ri: params[:ri]))
          },
        }
      end

      def show
        result = relay!(avatar_authority.group(params.expect(:id)))
        render(json: result.data) if result
      end

      def create
        result = relay!(avatar_authority.create_group(group_params.to_h))
        render(json: result.data, status: :created) if result
      end

      def update
        result = relay!(avatar_authority.update_group(params.expect(:id), group_params.to_h))
        render(json: result.data) if result
      end

      def destroy
        head(:no_content) if relay!(avatar_authority.archive_group(params.expect(:id)))
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

      def group_params
        params.expect(group: [:name, :description])
      end
    end
  end
end
