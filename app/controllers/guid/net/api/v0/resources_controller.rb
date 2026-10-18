# typed: false
# frozen_string_literal: true

module Guid
  module Net
    module Api
      module V0
        class ResourcesController < Guid::Net::BareController
          include ::ProblemDetailsRendering
          include ::ApiContentNegotiation

          AUTHENTICATION_MODE = :bare
          MAXIMUM_GUID_BYTES = 255

          before_action { response.set_header("Cache-Control", "no-store") }

          def show
            guid = params.expect(:guid).to_s
            return render_problem(:bad_request) unless transport_safe_guid?(guid)

            render_problem(:not_found)
          end

          private

          # This protects the HTTP boundary without selecting an issuance format. Future GUIDs remain
          # opaque; the route only refuses blank, invalidly encoded, control-bearing, or oversized
          # path components that cannot safely participate in resolution.
          def transport_safe_guid?(guid)
            guid.present? && guid.valid_encoding? && guid.bytesize <= MAXIMUM_GUID_BYTES && !guid.match?(/[\p{Cc}\s]/)
          end
        end
      end
    end
  end
end
