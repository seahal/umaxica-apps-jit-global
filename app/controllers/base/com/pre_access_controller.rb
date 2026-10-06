# typed: false
# frozen_string_literal: true

module Base
  module Com
    class PreAccessController < Base::Com::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private
    end
  end
end
