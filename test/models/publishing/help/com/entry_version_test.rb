# frozen_string_literal: true

require "test_helper"

module Publishing
  module Help
    module Com
      class EntryVersionTest < ActiveSupport::TestCase
        test "public_id is a fixed 21-character NanoID" do
          assert_public_id_fixed_length(::Publishing::Help::Com::EntryVersion)
        end
      end
    end
  end
end
