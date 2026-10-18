# typed: false
# frozen_string_literal: true

module Guid
  module Net
    module Api
      module V0
        class RevisionsController < Guid::Net::BareController
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
