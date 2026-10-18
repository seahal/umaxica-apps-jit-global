# typed: false
# frozen_string_literal: true

module Warp
  module App
    module Health
      class LivenessesController < BareController
        include ::HealthCheckRendering

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::App

        def show
          render_probe(::Health::LivenessCheck.call(profile: health_profile))
        end
      end
    end
  end
end
