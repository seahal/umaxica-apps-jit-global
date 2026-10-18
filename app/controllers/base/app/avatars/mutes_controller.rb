# typed: false
# frozen_string_literal: true

module Base
  module App
    module Avatars
      class MutesController < Base::App::FullAccessController
        include BaseAppAvatarSocialGraphActions

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private
        EDGE_KIND = "mutes"
      end
    end
  end
end
