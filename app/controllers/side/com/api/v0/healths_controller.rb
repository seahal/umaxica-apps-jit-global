# typed: false
# frozen_string_literal: true

module Side
  module Com
    module Api
      module V0
        # Machine-readable health aggregate: GET /api/v0/health.json.
        #
        # Bare on purpose: no session, no authentication, no database beyond the readiness probe's
        # own checks. Emits application/json only and refuses any Accept that excludes JSON with
        # 406 (MachineJsonNegotiation); never renders HTML or text/plain. Probe semantics come from
        # Health::*Check; the pass/warn/fail shape and the HTTP status from HealthStatusSerializer.
        class HealthsController < Side::Com::BareController
          include ::HealthCheckRendering
          include ::MachineJsonNegotiation

          AUTHENTICATION_MODE = :bare
          HEALTH_PROFILE = ::Health::Profiles::Com

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
