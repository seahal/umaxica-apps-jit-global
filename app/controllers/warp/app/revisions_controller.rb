# typed: false
# frozen_string_literal: true

module Warp
  module App
    # Deployment identifier endpoint. Bare on purpose: no session, no database,
    # and no dependency checks, so operators can identify a running deployment.
    class RevisionsController < BareController
      include ::ApplicationRevisionRendering

      AUTHENTICATION_MODE = :bare

      def show
        render_revision
      end
    end
  end
end
