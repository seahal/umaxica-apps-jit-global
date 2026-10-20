# frozen_string_literal: true

require "test_helper"

module Publishing
  module Help
    module App
      class EntryRevisionTest < ActiveSupport::TestCase
        test "public_id is a fixed 21-character NanoID" do
          assert_public_id_fixed_length(::Publishing::Help::App::EntryRevision)
        end
      end
    end
  end
end
