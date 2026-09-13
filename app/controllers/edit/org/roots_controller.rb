# typed: false
# frozen_string_literal: true

module Edit
  module Org
    class RootsController < BareController
      AUTHENTICATION_MODE = :bare

      allow_browser versions: :modern
      layout false

      public

      def index
      end
    end
  end
end
