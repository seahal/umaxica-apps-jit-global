# typed: false
# frozen_string_literal: true

module Xper
  module Com
    # Deployment identifier endpoint. Bare on purpose: no session, no database,
    # and no dependency checks, so operators can identify a running deployment.
    class RevisionsController < BareController
      include ::ApplicationRevisionRendering

      AUTHENTICATION_MODE = :bare

      public

      def show
        render_revision
      end
    end
  end
end
