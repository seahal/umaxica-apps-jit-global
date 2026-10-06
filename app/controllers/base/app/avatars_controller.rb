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

      def index
        authorize!(Avatar, to: :index?)
        avatars = switcher.available_avatars

        render inertia: true, props: {
          title: "Avatars",
          body: "avatars",
          empty: "None available",
          entries: avatars.map { |avatar| serialize_avatar_entry(avatar) },
          create_action: create_avatar_action,
          up_link: dashboard_up_link,
        }
      end

      def show
        avatar = find_avatar!
        authorize!(avatar)

        render inertia: true, props: {
          title: "Avatar",
          moniker: avatar.moniker,
          up_link: { label: t("actions.up"), href: base_app_avatars_path(ri: params[:ri]) },
          handle: avatar.active_handle&.handle,
          edit: { label: "Edit", href: edit_base_app_avatar_path(avatar.public_id, ri: params[:ri]) },
        }
      end

      def new
        authorize!(Avatar, to: :create?)

        render inertia: true, props: new_avatar_props(moniker_value: avatar_params[:moniker])
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
          owner_surface: "app",
          owner_collective_public_id: current_session&.selected_collective_public_id,
        )
        avatar = result.avatar || Avatar.new

        if result.success?
          redirect_to(base_app_avatar_path(avatar.public_id, ri: params[:ri]), status: :see_other)
        else
          error = result.errors.fetch(0)
          # Only a validation failure carries a record to report on the form. A unique-index
          # conflict that got past validation is raised and answered as 409 Conflict.
          raise error unless error.is_a?(ActiveRecord::RecordInvalid)

          render inertia: "base/app/avatars/new",
                 props: new_avatar_props(moniker_value: avatar_params[:moniker])
                   .merge(errors: creation_errors(error.record)),
                 status: :unprocessable_content
        end
      rescue AvatarProvisioning::Create::Unauthorized
        head :forbidden
      end

      def update
        avatar = find_avatar!
        authorize!(avatar)
        observed_owner = avatar.current_ownership_period ||
          raise(ActiveRecord::RecordNotFound, "Avatar has no current active owner")
        raise AvatarOwnerMembershipLockService::AuthorizationDenied, "app Avatar owner required" unless
          observed_owner.owner_surface == "app"

        result =
          AvatarOwnerMembershipLockService.call(
            actor: current_client,
            surface: "app",
            subject_public_id: Actor.selection.account_public_id,
            owner_collective_public_id: observed_owner.owner_collective_public_id,
            permission: "avatar.update",
          ) do
            Avatar.transaction do
              current_owner = AvatarOwnershipPeriod.current
                .where(avatar_id: avatar.id, avatar_ownership_status_id: AvatarOwnershipStatus::ACTIVE)
                .lock
                .first || raise(ActiveRecord::RecordNotFound, "Avatar has no current active owner")
              unless [current_owner.owner_surface, current_owner.owner_collective_public_id] ==
                  [observed_owner.owner_surface, observed_owner.owner_collective_public_id]
                raise AvatarOwnerMembershipLockService::AuthorizationDenied,
                      "Avatar owner changed while updating its moniker"
              end

              AvatarMonikerWriterOperation.call(
                avatar: avatar,
                moniker: avatar_params[:moniker],
                expected_current: :present,
              )
            end
          end
        if result.success?
          redirect_to(base_app_avatar_path(avatar.public_id, ri: params[:ri]), status: :see_other)
        else
          render inertia: "base/app/avatars/edit",
                 props: edit_avatar_props(avatar, moniker_value: avatar_params[:moniker])
                   .merge(errors: serialize_errors(result.errors)),
                 status: :unprocessable_content
        end
      rescue AvatarOwnerMembershipLockService::AuthorizationDenied
        head :forbidden
      end

      private

      # Creation is offered only while the selected persona has no active Avatar binding, because
      # the binding admits one active Avatar per persona.
      def create_avatar_action
        return nil if AvatarPersonaBinding.active.exists?(persona: current_persona)

        { label: "Create Avatar", href: new_base_app_avatar_path(ri: params[:ri]) }
      end

      def serialize_avatar_entry(avatar)
        {
          public_id: avatar.public_id,
          label: avatar.moniker,
          href: base_app_avatar_path(avatar.public_id, ri: params[:ri]),
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

      def edit_avatar_props(avatar, moniker_value: avatar.moniker)
        {
          title: "Avatar",
          heading: "Avatar",
          up_link: { label: t("actions.up"), href: base_app_avatar_path(avatar.public_id, ri: params[:ri]) },
          action: base_app_avatar_path(avatar.public_id, ri: params[:ri]),
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

      # Inertia reads validation errors from the `errors` page prop, keyed by the form field path.
      def serialize_errors(errors)
        errors.transform_keys { |attribute| "avatar.#{attribute}" }
          .transform_values { |messages| messages.first }
      end

      # A persona holds at most one active Avatar binding. That conflict belongs to no form field, so
      # it is reported under the form's own `avatar` key.
      def creation_errors(record)
        errors = serialize_errors(record.errors.to_hash.slice(:moniker, :handle))
        errors["avatar"] = t("base.app.avatars.already_assigned") if record.errors.of_kind?(:persona_id, :taken)
        errors
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
