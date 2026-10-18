# typed: false
# frozen_string_literal: true

module Tech
  module Org
    module Api
      module V0
        class RevisionsController < Tech::Org::BareController
          include ::ApplicationRevisionRendering
          include ::MachineJsonNegotiation

          AUTHENTICATION_MODE = :bare
          before_action :refuse_unless_machine_json_acceptable

          public

          def show
            render_revision_json
          end
        end
      end
    end
  end
end
