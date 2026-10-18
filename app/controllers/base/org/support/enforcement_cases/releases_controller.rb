# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      module EnforcementCases
        # adr/unified-enforcement.md, Administrative Access Lock integration / Break-glass, and
        # adr/operator-capability-authorization.md. Ending a Case releases the principal's access
        # lock only when no other in-force Case still blocks them (EnforcementCaseEndOperation's
        # refcount), and never revives a session, token, or Step-Up freshness.
        #
        # A permanent ban and a break-glass-only Case need a break-glass release with a second
        # approver. That flow is not provided through the console, so those Cases are refused here
        # rather than released under a weaker control than the one that applied them.
        class ReleasesController < Base::Org::ApplicationController
          include ::OrgOwnerPageRelay

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :no_store

          public

          # R5-WU12: decided, written and composed by the Enforcement owner over HTTPS.
          def new
            relay_owner_page!
          end

          # R5-WU12: decided, written and composed by the Enforcement owner over HTTPS.
          def create
            relay_owner_page!
          end

          private

          def no_store
            response.headers["Cache-Control"] = "private, no-store"
          end
        end
      end
    end
  end
end
