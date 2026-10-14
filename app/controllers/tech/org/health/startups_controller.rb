# typed: false
# frozen_string_literal: true

module Tech
  module Org
    module Health
      class StartupsController < Tech::Org::BareController
        include ::HealthCheckRendering

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::Org

        public

        def show
          render_probe(::Health::StartupCheck.call(profile: health_profile))
        end
      end
    end
  end
end
