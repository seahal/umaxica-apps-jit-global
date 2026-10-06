# typed: false
# frozen_string_literal: true

module Base
  module App
    class PreAccessController < Base::App::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private
    end
  end
end
