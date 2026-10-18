# typed: false
# frozen_string_literal: true

module Base
  module App
    # Avatar entity management for the app surface. Plural CRUD over the avatars assigned to the
    # signed-in client; changing the *current* avatar is the switcher's job. Requires a selected
    # actor context (FullAccessController).
    class AvatarsController < Base::App::FullAccessController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      HANDLE_MAXLENGTH = 80

      # R5-WU14: every Avatar read and write goes to the Avatar owner over HTTPS; this Base Self-RP
      # page renders the owner's allowlisted answer and makes no Avatar decision itself.
      def index
        result = avatar_result!(avatar_authority.avatars)
        return unless result

        render inertia: true, props: {
          title: "Avatars",
          body: "avatars",
          empty: "None available",
          entries: result.data.fetch("avatars").map { |avatar| serialize_avatar_entry(avatar) },
          create_action: create_avatar_action(result.data.fetch("can_create")),
          up_link: dashboard_up_link,
        }
      end

      def show
        result = avatar_result!(avatar_authority.avatar(params[:id]))
        return unless result

        avatar = result.data.fetch("avatar")
        render inertia: true, props: {
          title: "Avatar",
          moniker: avatar.fetch("moniker"),
          up_link: { label: t("actions.up"), href: base_app_avatars_path(ri: params[:ri]) },
          handle: avatar["handle"],
          edit: { label: "Edit", href: edit_base_app_avatar_path(avatar.fetch("public_id"), ri: params[:ri]) },
        }
      end

      def new
        return unless avatar_result!(avatar_authority.avatars)

        render inertia: true, props: new_avatar_props(moniker_value: avatar_params[:moniker])
      end

      def edit
        result = avatar_result!(avatar_authority.avatar(params[:id]))
        return unless result

        avatar = result.data.fetch("avatar")
        render inertia: true,
               props: edit_avatar_props(
                 avatar.fetch("public_id"),
                 moniker_value: avatar.fetch("moniker"),
               )
      end

      def create
        result = avatar_result!(avatar_authority.create_avatar(avatar_params.to_h))
        return unless result

        if result.ok?
          redirect_to(base_app_avatar_path(result.data.dig("avatar", "public_id"), ri: params[:ri]), status: :see_other)
        else
          render inertia: "base/app/avatars/new",
                 props: new_avatar_props(moniker_value: avatar_params[:moniker]).merge(errors: result.errors),
                 status: :unprocessable_content
        end
      end

      def update
        result = avatar_result!(avatar_authority.update_avatar(params[:id], avatar_params.slice(:moniker).to_h))
        return unless result

        if result.ok?
          redirect_to(base_app_avatar_path(params[:id], ri: params[:ri]), status: :see_other)
        else
          render inertia: "base/app/avatars/edit",
                 props: edit_avatar_props(
                   params[:id],
                   moniker_value: avatar_params[:moniker],
                 ).merge(errors: result.errors),
                 status: :unprocessable_content
        end
      end

      private

      def avatar_authority
        @avatar_authority ||= AvatarAuthorityClient.new(
          surface: "app",
          access_token: BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE),
          persona: Actor.selection.account_public_id,
        )
      end

      # Records the owner's decision for verify_authorized; 404 stays 404 and an unreachable owner is
      # a dependency failure, never a permission.
      def avatar_result!(result)
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

      # Creation is offered only while the selected persona has no active Avatar binding (the owner
      # answers this as can_create).
      def create_avatar_action(can_create)
        return nil unless can_create

        { label: "Create Avatar", href: new_base_app_avatar_path(ri: params[:ri]) }
      end

      def serialize_avatar_entry(avatar)
        {
          public_id: avatar.fetch("public_id"),
          label: avatar.fetch("moniker"),
          href: base_app_avatar_path(avatar.fetch("public_id"), ri: params[:ri]),
        }
      end

      def new_avatar_props(moniker_value: nil)
        {
          title: "New Avatar",
          heading: "New Avatar",
          up_link: { label: t("actions.up"), href: base_app_avatars_path(ri: params[:ri]) },
          action: base_app_avatars_path(ri: params[:ri]),
          method: "post",
          submit_label: "Create Avatar",
          moniker: moniker_field_props(moniker_value),
          handle: { label: "Handle", value: avatar_params[:handle].to_s, maxlength: HANDLE_MAXLENGTH },
        }
      end

      def edit_avatar_props(public_id, moniker_value:)
        {
          title: "Avatar",
          heading: "Avatar",
          up_link: { label: t("actions.up"), href: base_app_avatar_path(public_id, ri: params[:ri]) },
          action: base_app_avatar_path(public_id, ri: params[:ri]),
          method: "patch",
          submit_label: "Update Avatar",
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
            blank: t("base.app.avatars.moniker_validation.blank"),
            invalid: t("base.app.avatars.moniker_validation.invalid"),
            max_bytes: t("base.app.avatars.moniker_validation.max_bytes", count: max_bytes),
            max_graphemes: t(
              "base.app.avatars.moniker_validation.max_graphemes",
              count: max_grapheme_clusters,
            ),
          },
        }
      end

      def avatar_params
        params.fetch(:avatar, {}).permit(:moniker, :handle)
      end
    end
  end
end
