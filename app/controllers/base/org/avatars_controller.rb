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

      def show
        avatar = selected_avatar
        authorize!(avatar || Avatar, to: avatar ? :show? : :index?)

        render inertia: true, props: {
          title: "Avatar",
          avatar: avatar && { moniker: avatar.moniker },
          empty_message: avatar ? nil : t("base.org.avatars.none_selected"),
          action_link: avatar && { label: t("actions.edit"), href: edit_base_org_avatar_path(ri: params[:ri]) },
          switcher_link: { label: t("base.shared.dashboard.links.switcher"),
                           href: base_org_switcher_path(ri: params[:ri]), },
          up_link: dashboard_up_link,
        }
      end

      def edit
        avatar = selected_avatar!
        authorize!(avatar)

        render inertia: true, props: edit_avatar_props(avatar)
      end

      def update
        avatar = selected_avatar!
        authorize!(avatar)
        observed_owner = avatar.current_ownership_period ||
          raise(ActiveRecord::RecordNotFound, "Avatar has no current active owner")
        raise AvatarOwnerMembershipLockService::AuthorizationDenied, "org Avatar owner required" unless
          observed_owner.owner_surface == "org"

        result =
          AvatarOwnerMembershipLockService.call(
            actor: current_operator,
            surface: "org",
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
          redirect_to(base_org_avatar_path(ri: params[:ri]), status: :see_other)
        else
          render inertia: "base/org/avatars/edit",
                 props: edit_avatar_props(avatar, moniker_value: avatar_params[:moniker])
                   .merge(errors: serialize_errors(result.errors)),
                 status: :unprocessable_content
        end
      rescue AvatarOwnerMembershipLockService::AuthorizationDenied
        head :forbidden
      end

      def destroy
        avatar = selected_avatar!
        authorize!(avatar, to: :destroy?)
      end

      private

      def selected_avatar
        public_id = Actor.selection.avatar_public_id
        return if public_id.blank?

        switcher.find_avatar(public_id) || raise(ActiveRecord::RecordNotFound)
      end

      def selected_avatar!
        selected_avatar || raise(ActiveRecord::RecordNotFound, "no authorized Avatar is selected")
      end

      def edit_avatar_props(avatar, moniker_value: avatar.moniker)
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
            blank: t("base.app.avatars.moniker_validation.blank"),
            invalid: t("base.app.avatars.moniker_validation.invalid"),
            max_bytes: t("base.app.avatars.moniker_validation.max_bytes", count: max_bytes),
            max_graphemes: t(
              "base.app.avatars.moniker_validation.max_graphemes", count: max_grapheme_clusters,
            ),
          },
        }
      end

      def serialize_errors(errors)
        errors.transform_keys { |attribute| "avatar.#{attribute}" }
          .transform_values { |messages| messages.first }
      end

      def switcher
        @switcher ||= BaseSwitcherAuthority.new(
          surface: :org,
          principal: current_operator,
          session: current_session,
        )
      end

      def avatar_params
        params.fetch(:avatar, {}).permit(:moniker)
      end
    end
  end
end
