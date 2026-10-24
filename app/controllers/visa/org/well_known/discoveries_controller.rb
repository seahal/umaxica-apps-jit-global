# typed: false
# frozen_string_literal: true

module Visa
  module Org
    module WellKnown
      class DiscoveriesController < BareController
        AUTHENTICATION_MODE = :bare

        before_action :skip_metadata_session!

        def show
          render json: ::OidcDiscoveryDocument.for_resource_type("operator")
        end

        private

        def skip_metadata_session!
          request.session_options[:skip] = true
        end
      end
    end
  end
end
