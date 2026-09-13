# typed: false
# frozen_string_literal: true

module Base
  module App
    class LobbiesController < Base::App::ApplicationController
      include ::SignOutNotice
      include ::SurfaceInertiaPage
      include ::BaseLobbyPage

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open

      public

      def show
        render_lobby_page
      end
    end
  end
end
