# typed: false
# frozen_string_literal: true

module Base
  module Net
    module Api
      module V0
        # Machine-readable deployment identifier: GET /api/v0/revision.json.
        #
        # Bare on purpose: no session, no database, no dependency checks. Emits application/json
        # only ({"revision": "<sha>"} or {"revision": null}) and refuses any Accept that excludes
        # JSON with 406 (MachineJsonNegotiation); never renders HTML or text/plain. Shares its one
        # revision value with the text GET /revision endpoint through ApplicationRevisionRendering.
        class RevisionsController < Base::Net::BareController
          include ::ApplicationRevisionRendering
          include ::MachineJsonNegotiation

          AUTHENTICATION_MODE = :bare

          before_action :refuse_unless_machine_json_acceptable

          def show
            render_revision_json
          end
        end
      end
    end
  end
end
