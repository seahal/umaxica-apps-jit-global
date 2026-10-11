# typed: false
# frozen_string_literal: true

module Base
  module Org
    class AvatarsController < Base::Org::FullAccessController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def show
        authorize!(current_operator, to: :show?)
        render inertia: true, props: {
          title: "Avatar",
          body: "avatar",
          action_link: { label: t("actions.edit"), href: edit_base_org_avatar_path(ri: params[:ri]) },
        }
      end

      def edit
        authorize!(current_operator, to: :update?)
        render inertia: true, props: { title: "Avatar", body: "avatar" }
      end

      def update
        authorize!(current_operator, to: :update?)
        redirect_to(base_org_avatar_path(ri: params[:ri]), status: :see_other)
      end

      def destroy
        authorize!(current_operator, to: :destroy?)
        redirect_to(base_org_avatar_path(ri: params[:ri]), status: :see_other)
      end
    end
  end
end
