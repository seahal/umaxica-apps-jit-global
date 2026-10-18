# typed: false
# frozen_string_literal: true

module Base
  module Org
    class PreAccessController < Base::Org::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private
    end
  end
end
