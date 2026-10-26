# typed: false
# frozen_string_literal: true

module Visa
  module Org
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
