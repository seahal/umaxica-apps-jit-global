# typed: false
# frozen_string_literal: true

module Guid
  module Net
    class RootsController < BareController
      AUTHENTICATION_MODE = :bare

      allow_browser versions: :modern
      layout false

      def index
      end
    end
  end
end
