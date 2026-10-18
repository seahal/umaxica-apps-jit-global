# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      module EnforcementCases
        # adr/unified-enforcement.md, Approval: the approving operator must differ from the applying
        # operator -- enforced as a CHECK constraint (chk_*_enforcement_cases_approval_separation)
        # and by EnforcementCasePolicy#approve?. Effects are attached and confirmed at approval
        # time, never carried over unreviewed from the initial `create`.
        #
        # The approver is claimed under the Case row lock before the Case is applied, so two
        # concurrent approvals cannot both apply it: the second sees the recorded approver and is
        # refused as a conflict.
        class ApprovalsController < Base::Org::ApplicationController
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
