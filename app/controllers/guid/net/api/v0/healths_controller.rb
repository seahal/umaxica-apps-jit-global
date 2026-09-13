# typed: false
# frozen_string_literal: true

module Guid
  module Net
    module Api
      module V0
        class HealthsController < Guid::Net::BareController
          include ::HealthCheckRendering
          include ::MachineJsonNegotiation

          AUTHENTICATION_MODE = :bare
          HEALTH_PROFILE = ::Health::Profiles::Guid

          before_action :refuse_unless_machine_json_acceptable

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
