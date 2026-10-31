# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module Up
        module Guard
          class GooglesController < BaseController
            AUTHENTICATION_MODE = :open
            sign_entry_classification! :sign_up

            private

            def sign_up_family = "google"
          end
        end
      end
    end
  end
end
