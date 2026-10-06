# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      module Mfa
        class ResetsController < ::Base::Org::ApplicationController
          include ::SurfaceInertiaPage

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          public

          def show
            authorize!(current_operator, to: :show?)
            render inertia: true, props: {
              title: t("sign.app.settings.mfa.show.reset_title"),
              reset_unavailable: t("sign.app.settings.mfa.show.reset_unavailable"),
              back_link: {
                label: t("sign.app.settings.show.back"),
                href: base_org_identity_path(ri: params[:ri]),
              },
            }
          end

          protected

          def track_authenticated_session_activity?
            false
          end

          private
        end
      end
    end
  end
end
