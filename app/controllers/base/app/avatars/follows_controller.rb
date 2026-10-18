# typed: false
# frozen_string_literal: true

module Base
  module App
    module Avatars
      class FollowsController < Base::App::FullAccessController
        include BaseAppAvatarSocialGraphActions

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private
        EDGE_KIND = "follows"
      end
    end
  end
end
