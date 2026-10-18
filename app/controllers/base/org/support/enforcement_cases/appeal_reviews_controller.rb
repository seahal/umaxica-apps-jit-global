# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      module EnforcementCases
        # adr/unified-enforcement.md, Appeal: the reviewer must differ from the applying and the
        # approving operator (EnforcementAppeal#resolve!). An approved appeal ends the Case through
        # the same refcounted release path as any other ending.
        class AppealReviewsController < Base::Org::ApplicationController
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
