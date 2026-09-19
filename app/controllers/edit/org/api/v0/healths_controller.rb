# typed: false
# frozen_string_literal: true

module Edit
  module Org
    module Api
      module V0
        class HealthsController < Edit::Org::BareController
          include ::HealthCheckRendering
          include ::MachineJsonNegotiation

          AUTHENTICATION_MODE = :bare
          HEALTH_PROFILE = ::Health::Profiles::Org

          before_action :refuse_unless_machine_json_acceptable

          public

          public

          def show
            render_health_status(
              liveness: ::Health::LivenessCheck.call(profile: health_profile),
              readiness: ::Health::ReadinessCheck.call(profile: health_profile),
              startup: ::Health::StartupCheck.call(profile: health_profile),
            )
          end
        end
      end
    end
  end
end
