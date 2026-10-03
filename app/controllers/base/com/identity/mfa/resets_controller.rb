# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      module Mfa
        class ResetsController < ::Base::Com::ApplicationController
          include ::SurfaceInertiaPage

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_visitor!

          def show
            authorize!(current_visitor, to: :show?)
            render inertia: true, props: {
              title: t("sign.app.settings.mfa.show.reset_title"),
              reset_unavailable: t("sign.app.settings.mfa.show.reset_unavailable"),
              back_link: {
                label: t("sign.app.settings.show.back"),
                href: base_com_identity_path(ri: params[:ri]),
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
