# typed: false
# frozen_string_literal: true

module Base
  module App
    module Sign
      class EntriesController < Base::App::ApplicationController
        include ::OidcRpSignEntry

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        before_action :reject_authenticated_rp_start!
        helper_method :neutral_sign_form_url
      end
    end
  end
end
