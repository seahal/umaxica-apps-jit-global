# typed: false
# frozen_string_literal: true

module Visa
  module App
    class RevisionsController < BareController
      include ::ApplicationRevisionRendering

      AUTHENTICATION_MODE = :bare

      def show
        render_revision
      end
    end
  end
end
