# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module Up
        module Check
          module Telephone
            class BirthdatesController < ::Auth::App::Sign::Up::Check::Email::BirthdatesController
              AUTHENTICATION_MODE = :guest
              sign_entry_classification! :sign_up

              private

              def sign_up_family = "telephone"
            end
          end
        end
      end
    end
  end
end
