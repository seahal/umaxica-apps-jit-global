# typed: false
# frozen_string_literal: true

module Edit
  module Org
    class RootsController < Edit::Org::ApplicationController
      AUTHENTICATION_MODE = :open

      allow_browser versions: :modern
      layout false

      public

      def index
      end
    end
  end
end
