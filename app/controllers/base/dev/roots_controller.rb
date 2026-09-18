# typed: false
# frozen_string_literal: true

module Base
  module Dev
    class RootsController < Base::Dev::ApplicationController
      AUTHENTICATION_MODE = :deny_all

      layout false

      def index
      end
    end
  end
end
