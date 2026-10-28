# typed: false
# frozen_string_literal: true

module Base
  module Org
    # Operates only on the Avatar selected in the authenticated OperatorToken. The selected
    # identifier is re-resolved through current Bureau ownership and Agent membership on every
    # request; request parameters never choose the Avatar.
    class AvatarsController < Base::Org::FullAccessController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      public

      # R5-WU14: the selected Avatar is read and renamed by the Avatar owner over HTTPS.
      def show
        result = relay_avatar(avatar_authority.selected_avatar)
        return unless result

        avatar = result.data["avatar"]
        render inertia: true, props: {
          title: "Avatar",
          avatar: avatar && { moniker: avatar.fetch("moniker") },
          empty_message: avatar ? nil : t("base.org.avatars.none_selected"),
          action_link: avatar && { label: t("actions.edit"), href: edit_base_org_avatar_path(ri: params[:ri]) },
          switcher_link: { label: t("base.shared.dashboard.links.switcher"),
                           href: base_org_switcher_path(ri: params[:ri]), },
          up_link: dashboard_up_link,
        }
      end

      def edit
        result = relay_avatar(avatar_authority.selected_avatar)
        return unless result

        avatar = result.data["avatar"] || raise(ActiveRecord::RecordNotFound, "no authorized Avatar is selected")
        render inertia: true, props: edit_avatar_props(moniker_value: avatar.fetch("moniker"))
      end

      def update
        result = relay_avatar(avatar_authority.update_selected_avatar(avatar_params.slice(:moniker).to_h))
        return unless result

        if result.ok?
          redirect_to(base_org_avatar_path(ri: params[:ri]), status: :see_other)
        else
          render inertia: "base/org/avatars/edit",
                 props: edit_avatar_props(moniker_value: avatar_params[:moniker]).merge(errors: result.errors),
                 status: :unprocessable_content
        end
      end

      def destroy
        head(:no_content) if relay_avatar(avatar_authority.destroy_selected_avatar)
      end

      private

      def avatar_authority
        @avatar_authority ||= AvatarAuthorityClient.new(
          surface: "org",
          access_token: BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE),
          persona: Actor.selection.account_public_id,
        )
      end

      def relay_avatar(result)
        if result.status == :forbidden && result.data.to_h["error"] == "owner_denied"
          authorize!(result, to: :relay?, with: AvatarRemoteResultPolicy)
          head :forbidden
          return
        end
        authorize!(result, to: :show?, with: AvatarRemoteResultPolicy)
        raise ActiveRecord::RecordNotFound, "avatar not found" if result.status == :not_found

        if result.status == :dependency
          head :service_unavailable
          return
        end

        result
      end

      def edit_avatar_props(moniker_value:)
        {
          title: "Avatar",
          heading: "Avatar",
          action: base_org_avatar_path(ri: params[:ri]),
          method: "patch",
          submit_label: t("actions.update"),
          moniker: moniker_field_props(moniker_value),
          handle: nil,
        }
      end

      def moniker_field_props(value)
        max_bytes = AvatarMonikerValidator::MAX_BYTES
        max_grapheme_clusters = AvatarMonikerValidator::MAX_GRAPHEME_CLUSTERS

        {
          label: "Name",
          value: value.to_s,
          max_bytes: max_bytes,
          max_grapheme_clusters: max_grapheme_clusters,
          client_validation: {
            blank: t("base.org.avatars.moniker_validation.blank"),
            invalid: t("base.org.avatars.moniker_validation.invalid"),
            max_bytes: t("base.org.avatars.moniker_validation.max_bytes", count: max_bytes),
            max_graphemes: t(
              "base.org.avatars.moniker_validation.max_graphemes", count: max_grapheme_clusters,
            ),
          },
        }
      end

      def avatar_params
        params.fetch(:avatar, {}).permit(:moniker)
      end
    end
  end
end
