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

      MONIKER_MAXLENGTH = 120
      HANDLE_MAXLENGTH = 80

      before_action :authenticate_client!

      def index
        authorize!(Avatar, to: :index?)
        avatars = switcher.available_avatars

        render inertia: true, props: {
          title: "Avatars",
          body: "avatars",
          empty: "None available",
          entries: avatars.map { |avatar| serialize_avatar_entry(avatar) },
          create_action: { label: "Create Avatar" },
          up_link: dashboard_up_link(label: t("base.shared.dashboard.links.dashboard")),
        }
      end

      def show
        avatar = find_avatar!
        authorize!(avatar)

        render inertia: true, props: {
          title: "Avatar",
          moniker: avatar.moniker,
          handle: avatar.active_handle&.handle,
          edit: { label: "Edit", href: edit_base_app_avatar_path(avatar.public_id, ri: params[:ri]) },
        }
      end

      def new
        authorize!(Avatar, to: :create?)

        render inertia: true, props: new_avatar_props(Avatar.new)
      end

      def edit
        avatar = find_avatar!
        authorize!(avatar)

        render inertia: true, props: edit_avatar_props(avatar)
      end

      def create
        authorize!(Avatar, to: :create?)

        result = AvatarProvisioning::Create.call(
          actor: current_client,
          subject_type: :persona,
          subject: current_persona,
          avatar_params: avatar_params.except(:handle),
          handle_params: avatar_params.slice(:handle),
          organization_public_id: current_session&.selected_collective_public_id,
        )
        avatar = result.avatar || Avatar.new(avatar_params.except(:handle))

        if result.success?
          redirect_to(base_app_avatar_path(avatar.public_id, ri: params[:ri]), status: :see_other)
        else
          render inertia: "base/app/avatars/new",
                 props: new_avatar_props(avatar).merge(errors: serialize_errors(avatar)),
                 status: :unprocessable_content
        end
      end

      def update
        avatar = find_avatar!
        authorize!(avatar)
        if avatar.update(avatar_params.except(:handle))
          redirect_to(base_app_avatar_path(avatar.public_id, ri: params[:ri]), status: :see_other)
        else
          render inertia: "base/app/avatars/edit",
                 props: edit_avatar_props(avatar).merge(errors: serialize_errors(avatar)),
                 status: :unprocessable_content
        end
      end

      private

      def serialize_avatar_entry(avatar)
        {
          public_id: avatar.public_id,
          label: avatar.moniker.presence || avatar.public_id,
          href: base_app_avatar_path(avatar.public_id, ri: params[:ri]),
        }
      end

      def new_avatar_props(avatar)
        {
          title: "New Avatar",
          heading: "New Avatar",
          action: base_app_avatars_path(ri: params[:ri]),
          method: "post",
          submit_label: "Create Avatar",
          moniker: { label: "Name", value: avatar.moniker.to_s, maxlength: MONIKER_MAXLENGTH },
          handle: { label: "Handle", value: avatar_params[:handle].to_s, maxlength: HANDLE_MAXLENGTH },
        }
      end

      def edit_avatar_props(avatar)
        {
          title: "Avatar",
          heading: "Avatar",
          action: base_app_avatar_path(avatar.public_id, ri: params[:ri]),
          method: "patch",
          submit_label: "Update Avatar",
          moniker: { label: "Name", value: avatar.moniker.to_s, maxlength: MONIKER_MAXLENGTH },
          handle: nil,
        }
      end

      # Inertia reads validation errors from the `errors` page prop, keyed by the form field path.
      def serialize_errors(avatar)
        avatar.errors.to_hash.transform_keys { |attribute| "avatar.#{attribute}" }
          .transform_values { |messages| messages.first }
      end

      # Scoped to the principal's assigned avatars: a foreign or non-existent id raises
      # RecordNotFound (404), the authoritative ownership gate for show/edit/update.
      def find_avatar!
        switcher.find_avatar(params[:id]) || raise(ActiveRecord::RecordNotFound)
      end

      def switcher
        @switcher ||= BaseSwitcherAuthority.new(
          surface: :app, principal: current_client, session: current_session,
        )
      end

      def current_persona
        ClientPersona.find_by!(public_id: Actor.selection.account_public_id)
      end

      def avatar_params
        params.fetch(:avatar, {}).permit(:moniker, :handle)
      end
    end
  end
end
