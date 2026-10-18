# typed: false
# frozen_string_literal: true

module Base
  module App
    module Avatars
      class BlocksController < Base::App::FullAccessController
        include BaseAppAvatarSocialGraphActions

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private
        EDGE_KIND = "blocks"
      end
    end
  end
end
