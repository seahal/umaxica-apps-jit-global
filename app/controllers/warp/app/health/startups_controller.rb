# typed: false
# frozen_string_literal: true

module Warp
  module App
    module Health
      class StartupsController < BareController
        include ::HealthCheckRendering

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::App

        def show
          render_probe(::Health::StartupCheck.call(profile: health_profile))
        end
      end
    end
  end
end
